#include "libmyway_capture.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <gst/gst.h>
#include <glib.h>
#include <inttypes.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

// Globals to manage recording state
static gboolean is_recording = FALSE;
static GThread *recording_thread = NULL;
static GstElement *pipeline = NULL;
static int recording_duration_sec = 0;
static double current_recording_vu = 0.0;

// Globals to manage live audio monitor state
static gboolean is_monitoring = FALSE;
static GThread *monitor_thread = NULL;
static GstElement *monitor_pipeline = NULL;
static double current_monitor_vu = 0.0;

// Static array to hold exact PulseAudio device strings for sources
static char audio_device_strings[256][256];
static int audio_device_count = 0;


int myway_init(void) {
    GError *error = NULL;
    gboolean res = gst_init_check(NULL, NULL, &error);
    if (!res) {
        fprintf(stderr, "MyWay: Failed to initialize GStreamer: %s\n", error ? error->message : "Unknown error");
        if (error) g_error_free(error);
        return -1;
    }
    printf("myway_init called and GStreamer initialized\n");
    return 0;
}

// Enumerates PipeWire audio source nodes using GStreamer pulsedeviceprovider
MyWayAudioDevice* myway_get_audio_devices(int* count) {
    gst_init(NULL, NULL);
    
    // We use pulsedeviceprovider as it is standard and resolves PipeWire's pulse emulation nodes
    GstDeviceProvider *provider = gst_device_provider_factory_get_by_name("pulsedeviceprovider");
    if (!provider) {
        // Fallback to pipewiredeviceprovider if pulsedeviceprovider is unavailable
        provider = gst_device_provider_factory_get_by_name("pipewiredeviceprovider");
    }
    if (!provider) {
        *count = 0;
        return NULL;
    }
    
    GList *devices = gst_device_provider_get_devices(provider);
    int capacity = 16;
    MyWayAudioDevice* result = malloc(sizeof(MyWayAudioDevice) * capacity);
    int found = 0;
    
    for (GList *l = devices; l != NULL; l = l->next) {
        GstDevice *device = GST_DEVICE(l->data);
        gchar *klass = gst_device_get_device_class(device);
        
        // Filter for input/source devices
        if (klass && g_str_has_prefix(klass, "Audio/Source")) {
            gchar *name = gst_device_get_display_name(device);
            GstStructure *props = gst_device_get_properties(device);
            
            int id = -1;
            const gchar *dev_str = gst_structure_get_string(props, "device.string");
            
            if (dev_str && audio_device_count < 256) {
                // Use snprintf instead of strncpy for guaranteed NUL termination and safety (CP-ChangeComments / CP-SecurityAudit)
                snprintf(audio_device_strings[audio_device_count], sizeof(audio_device_strings[audio_device_count]), "%s", dev_str);
                id = audio_device_count;
                audio_device_count++;
            } else {
                // Fallback if device.string is missing, though pulsesrc might not like numeric strings
                const gchar *serial_str = gst_structure_get_string(props, "object.serial");
                if (serial_str && audio_device_count < 256) {
                    // Safe bounded copy with guaranteed NUL termination
                    snprintf(audio_device_strings[audio_device_count], sizeof(audio_device_strings[audio_device_count]), "%s", serial_str);
                    id = audio_device_count;
                    audio_device_count++;
                }
            }
            
            if (id >= 0 && name) {
                if (found >= capacity) {
                    capacity *= 2;
                    MyWayAudioDevice* new_result = realloc(result, sizeof(MyWayAudioDevice) * capacity);
                    if (new_result == NULL) {
                        break;
                    }
                    result = new_result;
                }
                
                result[found].id = id;
                // Safe bounded copy into device struct with guaranteed NUL termination
                snprintf(result[found].name, sizeof(result[found].name), "%s", name);
                found++;
            }
            
            if (name) g_free(name);
            if (props) gst_structure_free(props);
        }
        if (klass) g_free(klass);
    }
    
    g_list_free_full(devices, g_object_unref);
    g_object_unref(provider);
    
    *count = found;
    return result;
}

void myway_free_audio_devices(MyWayAudioDevice* devices) {
    if (devices) {
        free(devices);
    }
}

// Background thread loop to monitor GStreamer recording bus messages
static gpointer
recording_bus_thread(gpointer data) {
    GstBus *bus = gst_element_get_bus(pipeline);
    GstClockTime start_time = gst_clock_get_internal_time(gst_system_clock_obtain());
    GstClockTime last_status_time = start_time;
    
    while (is_recording) {
        GstMessage *msg = gst_bus_timed_pop_filtered(bus, 100 * GST_MSECOND,
                                                     GST_MESSAGE_EOS | GST_MESSAGE_ERROR | GST_MESSAGE_ELEMENT);
        if (msg) {
            if (GST_MESSAGE_TYPE(msg) == GST_MESSAGE_ERROR) {
                GError *err = NULL;
                gchar *dbg = NULL;
                gst_message_parse_error(msg, &err, &dbg);
                const gchar *src_name = (msg->src != NULL) ? GST_OBJECT_NAME(msg->src) : "unknown";
                fprintf(stderr, "MyWay GStreamer Error from %s: %s\n", src_name, err ? err->message : "Unknown");
                if (err) g_clear_error(&err);
                if (dbg) g_free(dbg);
                is_recording = FALSE;
            } else if (GST_MESSAGE_TYPE(msg) == GST_MESSAGE_EOS) {
                printf("MyWay GStreamer Bus: EOS received.\n");
                is_recording = FALSE;
            } else if (GST_MESSAGE_TYPE(msg) == GST_MESSAGE_ELEMENT) {
                const GstStructure *s = gst_message_get_structure(msg);
                if (s && gst_structure_has_name(s, "level")) {
                    const GValue *rms_val = gst_structure_get_value(s, "rms");
                    if (rms_val) {
                        guint size = 0;
                        gboolean is_value_array = FALSE;
                        GValueArray *arr = NULL;
                        
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
                        if (GST_VALUE_HOLDS_LIST(rms_val)) {
                            size = gst_value_list_get_size(rms_val);
                        } else if (GST_VALUE_HOLDS_ARRAY(rms_val)) {
                            size = gst_value_array_get_size(rms_val);
                        } else if (G_VALUE_HOLDS(rms_val, g_value_array_get_type())) {
                            arr = g_value_get_boxed(rms_val);
                            if (arr) {
                                size = arr->n_values;
                                is_value_array = TRUE;
                            }
                        }
#pragma GCC diagnostic pop
                        
                        double max_rms_db = -999.0;
                        for (guint i = 0; i < size; i++) {
                            const GValue *v = NULL;
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
                            if (is_value_array) {
                                v = g_value_array_get_nth(arr, i);
                            } else if (GST_VALUE_HOLDS_LIST(rms_val)) {
                                v = gst_value_list_get_value(rms_val, i);
                            } else {
                                v = gst_value_array_get_value(rms_val, i);
                            }
#pragma GCC diagnostic pop
                            if (v) {
                                double db = g_value_get_double(v);
                                if (db > max_rms_db) {
                                    max_rms_db = db;
                                }
                            }
                        }
                        
                        // Convert from dB (-60 to 0) to linear scale (0.0 to 1.0)
                        double linear_level = 0.0;
                        if (max_rms_db > -60.0) {
                            linear_level = (max_rms_db + 60.0) / 60.0;
                            if (linear_level > 1.0) linear_level = 1.0;
                            if (linear_level < 0.0) linear_level = 0.0;
                        }
                        
                        current_recording_vu = linear_level;
                    }
                }
            }
            gst_message_unref(msg);
        }
        
        // Update duration every second
        GstClockTime now = gst_clock_get_internal_time(gst_system_clock_obtain());
        if (now - last_status_time >= GST_SECOND) {
            recording_duration_sec++;
            last_status_time += GST_SECOND;
        }
    }
    
    gst_object_unref(bus);
    return NULL;
}

// Works out the recorded frame size from the source size.
//  - Non-square source pixels are converted to square ones.
//  - max_height > 0 scales DOWN (keeping the aspect ratio) to at most that
//    height; a source that is already that small is left alone (never upscaled).
//  - Both sides are rounded down to even numbers: the SVT-AV1 encoder refuses
//    odd sizes, which window captures and downscaling often produce.
static void
compute_output_size(int src_w, int src_h, int par_n, int par_d, int max_height,
                    int *out_w, int *out_h) {
    if (par_n <= 0 || par_d <= 0) { par_n = 1; par_d = 1; }
    double w = (double)src_w * par_n / par_d;
    double h = (double)src_h;
    if (max_height > 0 && h > max_height) {
        w = w * max_height / h;
        h = max_height;
    }
    int ow = (int)(w + 0.5);
    int oh = (int)(h + 0.5);
    ow &= ~1;
    oh &= ~1;
    if (ow < 2) ow = 2;
    if (oh < 2) oh = 2;
    *out_w = ow;
    *out_h = oh;
}

typedef struct {
    GstElement *capsfilter;
    int max_height;
} SizeProbeData;

static void
size_probe_data_free(gpointer p) {
    SizeProbeData *d = p;
    if (d->capsfilter) gst_object_unref(d->capsfilter);
    g_free(d);
}

// Runs on each new source format (including a window being resized) before
// videoscale sees it, and fixes the size videoscale must produce.
static GstPadProbeReturn
size_caps_probe_cb(GstPad *pad, GstPadProbeInfo *info, gpointer user_data) {
    (void)pad;
    SizeProbeData *d = user_data;
    GstEvent *ev = GST_PAD_PROBE_INFO_EVENT(info);
    if (!ev || GST_EVENT_TYPE(ev) != GST_EVENT_CAPS) return GST_PAD_PROBE_OK;

    GstCaps *caps = NULL;
    gst_event_parse_caps(ev, &caps);
    if (!caps || gst_caps_get_size(caps) < 1) return GST_PAD_PROBE_OK;
    const GstStructure *s = gst_caps_get_structure(caps, 0);
    int w = 0, h = 0, par_n = 1, par_d = 1;
    if (!gst_structure_get_int(s, "width", &w) || !gst_structure_get_int(s, "height", &h) ||
        w < 2 || h < 2) {
        return GST_PAD_PROBE_OK;
    }
    gst_structure_get_fraction(s, "pixel-aspect-ratio", &par_n, &par_d);

    int ow = 0, oh = 0;
    compute_output_size(w, h, par_n, par_d, d->max_height, &ow, &oh);
    printf("MyWay: source %dx%d -> recording %dx%d\n", w, h, ow, oh);

    GstCaps *out = gst_caps_new_simple("video/x-raw",
                                       "width", G_TYPE_INT, ow,
                                       "height", G_TYPE_INT, oh,
                                       "pixel-aspect-ratio", GST_TYPE_FRACTION, 1, 1,
                                       NULL);
    g_object_set(G_OBJECT(d->capsfilter), "caps", out, NULL);
    gst_caps_unref(out);
    return GST_PAD_PROBE_OK;
}

// Hooks the size probe onto the "scaler"/"sizecaps" pair in a parsed pipeline.
static int
attach_size_control(GstElement *pipe, int max_height) {
    GstElement *scaler = gst_bin_get_by_name(GST_BIN(pipe), "scaler");
    GstElement *sizecaps = gst_bin_get_by_name(GST_BIN(pipe), "sizecaps");
    if (!scaler || !sizecaps) {
        fprintf(stderr, "MyWay: size-control elements not found in pipeline\n");
        if (scaler) gst_object_unref(scaler);
        if (sizecaps) gst_object_unref(sizecaps);
        return -1;
    }
    GstPad *sinkpad = gst_element_get_static_pad(scaler, "sink");
    SizeProbeData *d = g_new0(SizeProbeData, 1);
    d->capsfilter = sizecaps;           // reference handed to the probe data
    d->max_height = max_height;
    gst_pad_add_probe(sinkpad, GST_PAD_PROBE_TYPE_EVENT_DOWNSTREAM,
                      size_caps_probe_cb, d, size_probe_data_free);
    gst_object_unref(sinkpad);
    gst_object_unref(scaler);
    return 0;
}

// Starts a capture session
int myway_start_capture(const MyWayCaptureParams* params) {
    if (is_recording || pipeline) {
        myway_stop_capture();
    }
    
    gst_init(NULL, NULL);
    
    const char *encoder_desc = "";
    const char *parser_desc = "";
    if (strcmp(params->codec, "h264") == 0) {
        encoder_desc = "x264enc bitrate=%d speed-preset=ultrafast tune=zerolatency";
        parser_desc = "h264parse";
    } else if (strcmp(params->codec, "h265") == 0) {
        encoder_desc = "x265enc bitrate=%d speed-preset=ultrafast tune=zerolatency";
        parser_desc = "h265parse";
    } else if (strcmp(params->codec, "av1") == 0) {
        // gst-plugins-bad svtav1enc (GStreamer 1.22+) takes target-bitrate in kbps.
        // It has no "bitrate" property; using one made every AV1 recording fail.
        encoder_desc = "svtav1enc target-bitrate=%d preset=12";
        parser_desc = "av1parse";
    } else {
        encoder_desc = "x264enc bitrate=%d speed-preset=ultrafast tune=zerolatency";
        parser_desc = "h264parse";
    }
    
    // Format the encoder string with the bitrate (all three encoders take kbps)
    char encoder_formatted[512];
    snprintf(encoder_formatted, sizeof(encoder_formatted), encoder_desc, params->video_bitrate);

    // Output size control: always present. A pad probe sets the exact output
    // size once the source size is known (see size_caps_probe_cb): scaled down
    // to max_height when asked, never up, and always even.
    const char *scale_desc = "videoscale name=scaler ! capsfilter name=sizecaps ! ";

    // The output path is NOT interpolated into the pipeline description: a
    // user-chosen folder may contain quotes or other characters that would
    // change the description. The filesink is named and its location is set
    // as a property after parsing.
    char *desc = NULL;
    const char *display = getenv("DISPLAY");
    if (!display) display = ":1";

    if (params->is_wayland) {
        if (params->audio_node_id >= 0 && params->audio_node_id < audio_device_count) {
            desc = g_strdup_printf(
                "pipewiresrc fd=%d name=vsrc path=\"%lu\" ! queue ! videoconvert ! %s%s ! %s ! queue ! mp4mux name=mux faststart=true ! filesink name=fsink "
                "pulsesrc device=\"%s\" ! queue ! audioconvert ! level name=level ! audioresample ! voaacenc ! queue ! mux.",
                params->wayland_fd, params->video_node_id, scale_desc, encoder_formatted, parser_desc, audio_device_strings[params->audio_node_id]
            );
        } else {
            desc = g_strdup_printf(
                "pipewiresrc fd=%d name=vsrc path=\"%lu\" ! queue ! videoconvert ! %s%s ! %s ! queue ! mp4mux name=mux faststart=true ! filesink name=fsink",
                params->wayland_fd, params->video_node_id, scale_desc, encoder_formatted, parser_desc
            );
        }
    } else {
        // X11 Capture using ximagesrc
        const char *xid_prop = "";
        char xid_buffer[64] = "";
        if (strcmp(params->mode, "window") == 0 && params->video_node_id > 0) {
            snprintf(xid_buffer, sizeof(xid_buffer), "xid=%" PRIu64, params->video_node_id);
            xid_prop = xid_buffer;
        }

        if (params->audio_node_id >= 0 && params->audio_node_id < audio_device_count) {
            desc = g_strdup_printf(
                "ximagesrc name=vsrc display-name=\"%s\" %s ! queue ! videoconvert ! %s%s ! %s ! queue ! mp4mux name=mux faststart=true ! filesink name=fsink "
                "pulsesrc device=\"%s\" ! queue ! audioconvert ! level name=level ! audioresample ! voaacenc ! queue ! mux.",
                display, xid_prop, scale_desc, encoder_formatted, parser_desc, audio_device_strings[params->audio_node_id]
            );
        } else {
            desc = g_strdup_printf(
                "ximagesrc name=vsrc display-name=\"%s\" %s ! queue ! videoconvert ! %s%s ! %s ! queue ! mp4mux name=mux faststart=true ! filesink name=fsink",
                display, xid_prop, scale_desc, encoder_formatted, parser_desc
            );
        }
    }
    
    printf("MyWay: Launching GStreamer pipeline: %s\n", desc);
    
    GError *error = NULL;
    pipeline = gst_parse_launch(desc, &error);
    g_free(desc);
    
    if (error || !pipeline) {
        // Typically a missing GStreamer element, e.g. svtav1enc for AV1.
        fprintf(stderr, "MyWay GStreamer Parse Error: %s\n", error ? error->message : "unknown");
        if (error) g_error_free(error);
        if (pipeline) {
            gst_object_unref(pipeline);
            pipeline = NULL;
        }
        return -1;
    }
    
    GstElement *fsink = gst_bin_get_by_name(GST_BIN(pipeline), "fsink");
    if (!fsink) {
        fprintf(stderr, "MyWay: filesink not found in pipeline\n");
        gst_object_unref(pipeline);
        pipeline = NULL;
        return -1;
    }
    g_object_set(G_OBJECT(fsink), "location", params->output_path, NULL);
    gst_object_unref(fsink);

    int max_height = (params->max_height > 0 && params->max_height <= 4320) ? params->max_height : 0;
    if (attach_size_control(pipeline, max_height) != 0) {
        gst_object_unref(pipeline);
        pipeline = NULL;
        return -1;
    }

    is_recording = TRUE;
    recording_duration_sec = 0;
    current_recording_vu = 0.0;
    
    gst_element_set_state(pipeline, GST_STATE_PLAYING);
    recording_thread = g_thread_new("recording-bus", recording_bus_thread, NULL);
    
    return 0;
}

// Stops recording and flushes the pipeline (crucial for MP4 metadata writing)
int myway_is_recording(void) {
    return is_recording ? 1 : 0;
}

int myway_stop_capture(void) {
    // A pipeline that stopped itself on an error has is_recording == FALSE but
    // still needs tearing down, so only bail out when there is nothing at all.
    if (!is_recording && !pipeline) return 0;

    if (pipeline && is_recording) {
        printf("MyWay: Sending EOS to pipeline for clean MP4 writing...\n");
        gst_element_send_event(pipeline, gst_event_new_eos());
        
        // Wait for the bus to receive EOS, up to 2 seconds
        GstBus *bus = gst_element_get_bus(pipeline);
        GstMessage *msg = gst_bus_timed_pop_filtered(bus, 2 * GST_SECOND, GST_MESSAGE_EOS);
        if (msg) {
            printf("MyWay: Received EOS confirmation from pipeline.\n");
            gst_message_unref(msg);
        } else {
            printf("MyWay WARNING: Timeout waiting for EOS. MP4 file might be corrupted/incomplete.\n");
        }
        gst_object_unref(bus);
    }
    
    is_recording = FALSE;
    if (recording_thread) {
        g_thread_join(recording_thread);
        recording_thread = NULL;
    }
    
    if (pipeline) {
        gst_element_set_state(pipeline, GST_STATE_NULL);
        gst_object_unref(pipeline);
        pipeline = NULL;
    }
    
    current_recording_vu = 0.0;
    recording_duration_sec = 0;
    return 0;
}

// Background thread loop to monitor GStreamer live audio monitor bus messages
static gpointer
monitor_bus_thread(gpointer data) {
    GstBus *bus = gst_element_get_bus(monitor_pipeline);
    
    while (is_monitoring) {
        GstMessage *msg = gst_bus_timed_pop_filtered(bus, 100 * GST_MSECOND,
                                                     GST_MESSAGE_EOS | GST_MESSAGE_ERROR | GST_MESSAGE_ELEMENT);
        if (msg) {
            if (GST_MESSAGE_TYPE(msg) == GST_MESSAGE_ELEMENT) {
                const GstStructure *s = gst_message_get_structure(msg);
                if (s && gst_structure_has_name(s, "level")) {
                    const GValue *rms_val = gst_structure_get_value(s, "rms");
                    if (rms_val) {
                        guint size = 0;
                        gboolean is_value_array = FALSE;
                        GValueArray *arr = NULL;
                        
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
                        if (GST_VALUE_HOLDS_LIST(rms_val)) {
                            size = gst_value_list_get_size(rms_val);
                        } else if (GST_VALUE_HOLDS_ARRAY(rms_val)) {
                            size = gst_value_array_get_size(rms_val);
                        } else if (G_VALUE_HOLDS(rms_val, g_value_array_get_type())) {
                            arr = g_value_get_boxed(rms_val);
                            if (arr) {
                                size = arr->n_values;
                                is_value_array = TRUE;
                            }
                        }
#pragma GCC diagnostic pop
                        
                        double max_rms_db = -999.0;
                        for (guint i = 0; i < size; i++) {
                            const GValue *v = NULL;
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
                            if (is_value_array) {
                                v = g_value_array_get_nth(arr, i);
                            } else if (GST_VALUE_HOLDS_LIST(rms_val)) {
                                v = gst_value_list_get_value(rms_val, i);
                            } else {
                                v = gst_value_array_get_value(rms_val, i);
                            }
#pragma GCC diagnostic pop
                            if (v) {
                                double db = g_value_get_double(v);
                                if (db > max_rms_db) {
                                    max_rms_db = db;
                                }
                            }
                        }
                        
                        double linear_level = 0.0;
                        if (max_rms_db > -60.0) {
                            linear_level = (max_rms_db + 60.0) / 60.0;
                            if (linear_level > 1.0) linear_level = 1.0;
                            if (linear_level < 0.0) linear_level = 0.0;
                        }
                        
                        current_monitor_vu = linear_level;
                    }
                }
            }
            gst_message_unref(msg);
        }
    }
    
    gst_object_unref(bus);
    return NULL;
}

// Starts monitoring an audio device for live VU levels
int myway_start_audio_monitor(int audio_node_id) {
    if (is_monitoring) {
        myway_stop_audio_monitor();
    }
    
    gst_init(NULL, NULL);
    
    char *desc = NULL;
    if (audio_node_id >= 0 && audio_node_id < audio_device_count) {
        desc = g_strdup_printf(
            "pulsesrc device=\"%s\" ! queue ! audioconvert ! level name=level ! fakesink",
            audio_device_strings[audio_node_id]
        );
    } else {
        desc = g_strdup("pulsesrc ! queue ! audioconvert ! level name=level ! fakesink");
    }
    
    GError *error = NULL;
    monitor_pipeline = gst_parse_launch(desc, &error);
    g_free(desc);
    
    if (error) {
        fprintf(stderr, "MyWay monitor GStreamer Parse Error: %s\n", error->message);
        g_error_free(error);
        return -1;
    }
    
    is_monitoring = TRUE;
    current_monitor_vu = 0.0;
    
    gst_element_set_state(monitor_pipeline, GST_STATE_PLAYING);
    monitor_thread = g_thread_new("monitor-bus", monitor_bus_thread, NULL);
    
    return 0;
}

// Stops audio monitoring
int myway_stop_audio_monitor(void) {
    if (!is_monitoring) return 0;
    
    is_monitoring = FALSE;
    if (monitor_thread) {
        g_thread_join(monitor_thread);
        monitor_thread = NULL;
    }
    
    if (monitor_pipeline) {
        gst_element_set_state(monitor_pipeline, GST_STATE_NULL);
        gst_object_unref(monitor_pipeline);
        monitor_pipeline = NULL;
    }
    
    current_monitor_vu = 0.0;
    return 0;
}

// Getters for polling from Dart FFI
double myway_get_recording_vu(void) {
    return current_recording_vu;
}

int myway_get_recording_duration(void) {
    return recording_duration_sec;
}

double myway_get_monitor_vu(void) {
    return current_monitor_vu;
}

// Frees resources
void myway_teardown(void) {
    myway_stop_capture();
    myway_stop_audio_monitor();
}

static int extraction_socket = -1;
static char current_socket_path[256] = {0};

void myway_setup_fd_extraction(const char* socket_path) {
    if (extraction_socket != -1) {
        close(extraction_socket);
        unlink(current_socket_path);
    }
    
    // Safe bounded copy with guaranteed NUL-termination (CP-SecurityAudit)
    snprintf(current_socket_path, sizeof(current_socket_path), "%s", socket_path);
    
    extraction_socket = socket(AF_UNIX, SOCK_STREAM, 0);
    if (extraction_socket < 0) return;
    
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    // Safe bounded copy into sockaddr_un with guaranteed NUL-termination
    snprintf(addr.sun_path, sizeof(addr.sun_path), "%s", socket_path);
    
    unlink(socket_path);

    // Restrict the socket to the owner (0600) so no other local user can
    // connect and grab the screen-capture file descriptor. Set a tight umask
    // across bind() (which honours umask for the created node), then restore it,
    // and chmod() explicitly as belt-and-suspenders.
    mode_t old_umask = umask(0077);
    if (bind(extraction_socket, (struct sockaddr*)&addr, sizeof(addr)) != 0) {
        umask(old_umask);
        close(extraction_socket);
        extraction_socket = -1;
        return;
    }
    umask(old_umask);
    chmod(socket_path, 0600);
    listen(extraction_socket, 1);
}

int myway_read_extracted_fd(void) {
    if (extraction_socket < 0) return -1;
    
    int client = accept(extraction_socket, NULL, NULL);
    if (client < 0) return -1;

    struct msghdr msg = {0};
    char buf[1];
    struct iovec io = { .iov_base = buf, .iov_len = 1 };
    msg.msg_iov = &io;
    msg.msg_iovlen = 1;

    char c_buffer[256];
    msg.msg_control = c_buffer;
    msg.msg_controllen = sizeof(c_buffer);

    if (recvmsg(client, &msg, 0) < 0) {
        close(client);
        return -1;
    }

    struct cmsghdr *cmsg = CMSG_FIRSTHDR(&msg);
    int received_fd = -1;
    if (cmsg && cmsg->cmsg_level == SOL_SOCKET && cmsg->cmsg_type == SCM_RIGHTS) {
        memcpy(&received_fd, CMSG_DATA(cmsg), sizeof(int));
    }

    close(client);
    close(extraction_socket);
    extraction_socket = -1;
    unlink(current_socket_path);
    
    return received_fd;
}
