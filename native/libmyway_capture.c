#include "libmyway_capture.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int myway_init(void) {
    // Placeholder for portal and PipeWire initialization
    printf("myway_init called\n");
    return 0;
}

MyWayAudioDevice* myway_get_audio_devices(int* count) {
    // Placeholder
    *count = 0;
    return NULL;
}

int myway_start_capture(const MyWayCaptureParams* params, MyWayStatusCallback cb, void* user_data) {
    // Placeholder
    printf("myway_start_capture called with output_path: %s\n", params->output_path);
    return 0;
}

int myway_stop_capture(void) {
    // Placeholder
    printf("myway_stop_capture called\n");
    return 0;
}

void myway_teardown(void) {
    // Placeholder
    printf("myway_teardown called\n");
}
