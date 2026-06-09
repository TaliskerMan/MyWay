#include <stdio.h>
#include <stdlib.h>
#include "native/libmyway_capture.h"
int main() {
    int count = 0;
    MyWayAudioDevice* devs = myway_get_audio_devices(&count);
    for(int i=0; i<count; i++) {
        printf("Device %d: id=%d, name=%s\n", i, devs[i].id, devs[i].name);
    }
    myway_free_audio_devices(devs);
    return 0;
}
