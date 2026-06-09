#include <gst/gst.h>
#include <stdio.h>

int main(int argc, char *argv[]) {
    gst_init(&argc, &argv);
    GstDeviceProvider *provider = gst_device_provider_factory_get_by_name("pulsedeviceprovider");
    if (!provider) { printf("No pulsedeviceprovider\n"); return 1; }
    
    gst_device_provider_start(provider);
    GList *devices = gst_device_provider_get_devices(provider);
    for (GList *l = devices; l != NULL; l = l->next) {
        GstDevice *dev = l->data;
        gchar *name = gst_device_get_display_name(dev);
        GstStructure *props = gst_device_get_properties(dev);
        
        const gchar *serial = gst_structure_get_string(props, "object.serial");
        int id = 0;
        gst_structure_get_int(props, "object.id", &id);
        const gchar *dev_str = gst_structure_get_string(props, "device.string");
        const gchar *dev_name = gst_structure_get_string(props, "device.name");
        
        printf("Display Name: %s\n", name);
        printf("  object.serial: %s\n", serial ? serial : "null");
        printf("  object.id: %d\n", id);
        printf("  device.string: %s\n", dev_str ? dev_str : "null");
        printf("  device.name: %s\n", dev_name ? dev_name : "null");
        
        g_free(name);
        gst_structure_free(props);
    }
    gst_device_provider_stop(provider);
    return 0;
}
