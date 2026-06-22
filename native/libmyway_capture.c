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

// Struct to pass to the crop pad probe
typedef struct {
    int area_x;
    int area_y;
    int area_width;
    int area_height;
    GstElement *crop_el;
} CropProbeData;

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
                strncpy(audio_device_strings[audio_device_count], dev_str, 255);
                audio_device_strings[audio_device_count][255] = '\0';
                id = audio_device_count;
                audio_device_count++;
            } else {
                // Fallback if device.string is missing, though pulsesrc might not like numeric strings
                const gchar *serial_str = gst_structure_get_string(props, "object.serial");
                if (serial_str && audio_device_count < 256) {
                    strncpy(audio_device_strings[audio_device_count], serial_str, 255);
                    audio_device_strings[audio_device_count][255] = '\0';
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
                strncpy(result[found].name, name, 255);
                result[found].name[255] = '\0';
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

// Pad probe callback to calculate and apply crop margins dynamically
static GstPadProbeReturn
crop_pad_probe_cb(GstPad *pad, GstPadProbeInfo *info, gpointer user_data) {
    CropProbeData *data = (CropProbeData *)user_data;
    GstCaps *caps = gst_pad_get_current_caps(pad);
    if (caps) {
        GstStructure *s = gst_caps_get_structure(caps, 0);
        int width = 0, height = 0;
        if (gst_structure_get_int(s, "width", &width) && gst_structure_get_int(s, "height", &height)) {
            int left = data->area_x;
            int top = data->area_y;
            int right = width - (left + data->area_width);
            int bottom = height - (top + data->area_height);
            
            // Boundary checks
            if (left < 0) left = 0;
            if (top < 0) top = 0;
            if (right < 0) right = 0;
            if (bottom < 0) bottom = 0;
            
            g_object_set(data->crop_el,
                         "left", left,
                         "top", top,
                         "right", right,
                         "bottom", bottom,
                         NULL);
            printf("MyWay Crop: Applied left=%d, top=%d, right=%d, bottom=%d (Source resolution: %dx%d)\n",
                   left, top, right, bottom, width, height);
        }
        gst_caps_unref(caps);
    }
    return GST_PAD_PROBE_REMOVE; // Remove probe after the first buffer
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

// Starts a capture session
int myway_start_capture(const MyWayCaptureParams* params) {
    if (is_recording) {
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
        encoder_desc = "svtav1enc bitrate=%d preset=12";
        parser_desc = "av1parse";
    } else {
        encoder_desc = "x264enc bitrate=%d speed-preset=ultrafast tune=zerolatency";
        parser_desc = "h264parse";
    }
    
    // Format the encoder string with the bitrate
    char encoder_formatted[512];
    if (strcmp(params->codec, "av1") == 0) {
        // svtav1enc expects bps
        snprintf(encoder_formatted, sizeof(encoder_formatted), encoder_desc, params->video_bitrate * 1000);
    } else {
        // x264enc/x265enc expects kbps
        snprintf(encoder_formatted, sizeof(encoder_formatted), encoder_desc, params->video_bitrate);
    }
    
    char *desc = NULL;
    const char *display = getenv("DISPLAY");
    if (!display) display = ":1";

    if (params->is_wayland) {
        if (params->audio_node_id >= 0 && params->audio_node_id < audio_device_count) {
            desc = g_strdup_printf(
                "pipewiresrc fd=%d name=vsrc path=\"%lu\" ! queue ! videocrop name=crop ! videoconvert ! %s ! %s ! queue ! mp4mux name=mux faststart=true ! filesink location=\"%s\" "
                "pulsesrc device=\"%s\" ! queue ! audioconvert ! level name=level ! audioresample ! voaacenc ! queue ! mux.",
                params->wayland_fd, params->video_node_id, encoder_formatted, parser_desc, params->output_path, audio_device_strings[params->audio_node_id]
            );
        } else {
            desc = g_strdup_printf(
                "pipewiresrc fd=%d name=vsrc path=\"%lu\" ! queue ! videocrop name=crop ! videoconvert ! %s ! %s ! queue ! mp4mux name=mux faststart=true ! filesink location=\"%s\"",
                params->wayland_fd, params->video_node_id, encoder_formatted, parser_desc, params->output_path
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
                "ximagesrc name=vsrc display-name=\"%s\" %s ! queue ! videoconvert ! %s ! %s ! queue ! mp4mux name=mux faststart=true ! filesink location=\"%s\" "
                "pulsesrc device=\"%s\" ! queue ! audioconvert ! level name=level ! audioresample ! voaacenc ! queue ! mux.",
                display, xid_prop, encoder_formatted, parser_desc, params->output_path, audio_device_strings[params->audio_node_id]
            );
        } else {
            desc = g_strdup_printf(
                "ximagesrc name=vsrc display-name=\"%s\" %s ! queue ! videoconvert ! %s ! %s ! queue ! mp4mux name=mux faststart=true ! filesink location=\"%s\"",
                display, xid_prop, encoder_formatted, parser_desc, params->output_path
            );
        }
    }
    
    printf("MyWay: Launching GStreamer pipeline: %s\n", desc);
    
    GError *error = NULL;
    pipeline = gst_parse_launch(desc, &error);
    g_free(desc);
    
    if (error) {
        fprintf(stderr, "MyWay GStreamer Parse Error: %s\n", error->message);
        g_error_free(error);
        return -1;
    }
    
    // Set up crop for X11 (using startx/starty/endx/endy on ximagesrc)
    if (params->is_wayland == 0 && strcmp(params->mode, "area") == 0 && params->area_width > 0 && params->area_height > 0) {
        GstElement *vsrc = gst_bin_get_by_name(GST_BIN(pipeline), "vsrc");
        if (vsrc) {
            g_object_set(G_OBJECT(vsrc),
                         "startx", params->area_x,
                         "starty", params->area_y,
                         "endx", params->area_x + params->area_width - 1,
                         "endy", params->area_y + params->area_height - 1,
                         NULL);
            gst_object_unref(vsrc);
        }
    }

    
    
    // Set up crop probe if mode is area and coordinates are valid (Wayland only)
    if (params->is_wayland && strcmp(params->mode, "area") == 0 && params->area_width > 0 && params->area_height > 0) {
        GstElement *vsrc = gst_bin_get_by_name(GST_BIN(pipeline), "vsrc");
        GstElement *crop = gst_bin_get_by_name(GST_BIN(pipeline), "crop");
        if (vsrc && crop) {
            GstPad *srcpad = gst_element_get_static_pad(vsrc, "src");
            if (srcpad) {
                CropProbeData *probe_data = g_new0(CropProbeData, 1);
                probe_data->area_x = params->area_x;
                probe_data->area_y = params->area_y;
                probe_data->area_width = params->area_width;
                probe_data->area_height = params->area_height;
                probe_data->crop_el = crop;
                
                gst_pad_add_probe(srcpad, GST_PAD_PROBE_TYPE_BUFFER,
                                  crop_pad_probe_cb, probe_data, g_free);
                gst_object_unref(srcpad);
            }
            gst_object_unref(vsrc);
            gst_object_unref(crop);
        }
    }
    
    is_recording = TRUE;
    recording_duration_sec = 0;
    current_recording_vu = 0.0;
    
    gst_element_set_state(pipeline, GST_STATE_PLAYING);
    recording_thread = g_thread_new("recording-bus", recording_bus_thread, NULL);
    
    return 0;
}

// Stops recording and flushes the pipeline (crucial for MP4 metadata writing)
int myway_stop_capture(void) {
    if (!is_recording) return 0;
    
    if (pipeline) {
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
    
    strncpy(current_socket_path, socket_path, sizeof(current_socket_path) - 1);
    
    extraction_socket = socket(AF_UNIX, SOCK_STREAM, 0);
    if (extraction_socket < 0) return;
    
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, socket_path, sizeof(addr.sun_path)-1);
    
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
