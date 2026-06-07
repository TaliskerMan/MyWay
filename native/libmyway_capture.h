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
    int audio_node_id;
    char output_path[1024];
    int area_x;
    int area_y;
    int area_width;
    int area_height;
} MyWayCaptureParams;

typedef void (*MyWayStatusCallback)(int duration_sec, int bitrate_kbps, int frame_drops, double vu_level, void* user_data);

// Initializes portal and PipeWire
int myway_init(void);

// Enumerates PipeWire audio source nodes
MyWayAudioDevice* myway_get_audio_devices(int* count);

// Starts a capture session
int myway_start_capture(const MyWayCaptureParams* params, MyWayStatusCallback cb, void* user_data);

// Stops recording and flushes the pipeline
int myway_stop_capture(void);

// Frees resources
void myway_teardown(void);

#ifdef __cplusplus
}
#endif

#endif // LIBMYWAY_CAPTURE_H
