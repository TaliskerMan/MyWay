#ifndef LIBMYWAY_CAPTURE_H
#define LIBMYWAY_CAPTURE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int id;
    char name[256];
} MyWayAudioDevice;

typedef struct {
    char mode[32]; // "fullscreen", "window", "area"
    char codec[16]; // "h265", "h264", "av1"
    int video_bitrate;
    uint64_t video_node_id; // Added for Wayland PipeWire stream node ID
    int audio_node_id;
    char output_path[1024];
    int area_x;
    int area_y;
    int area_width;
    int area_height;
    int is_wayland; // 1 for Wayland (PipeWire), 0 for X11 (ximagesrc)
    int wayland_fd;
    int max_height; // 0 = record at source resolution; otherwise scale DOWN to at most this height
} MyWayCaptureParams;

// Initializes portal and PipeWire
int myway_init(void);

// Enumerates PipeWire audio source nodes
MyWayAudioDevice* myway_get_audio_devices(int* count);

// Frees the device list allocated by myway_get_audio_devices
void myway_free_audio_devices(MyWayAudioDevice* devices);

// Starts a capture session
int myway_start_capture(const MyWayCaptureParams* params);

// Stops recording and flushes the pipeline
int myway_stop_capture(void);

// Starts monitoring an audio device for live VU levels
int myway_start_audio_monitor(int audio_node_id);

// Stops audio monitoring
int myway_stop_audio_monitor(void);

// Getters for polling from Dart FFI
double myway_get_recording_vu(void);
int myway_get_recording_duration(void);
// 1 while a recording is running; 0 once it has stopped, including when the
// pipeline stopped by itself because of an error.
int myway_is_recording(void);
double myway_get_monitor_vu(void);

// Frees all resources
void myway_teardown(void);

// Setup a unix socket server to receive the FD from Dart
void myway_setup_fd_extraction(const char* socket_path);

// Accept connection and read the FD sent via SCM_RIGHTS
int myway_read_extracted_fd(void);

// Fetch PipeWire remote FD using XDG Desktop Portal
int myway_open_pipewire_remote(const char* session_handle);

#ifdef __cplusplus
}
#endif

#endif // LIBMYWAY_CAPTURE_H
