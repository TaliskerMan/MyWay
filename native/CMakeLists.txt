cmake_minimum_required(VERSION 3.10)
project(libmyway_capture)

find_package(PkgConfig REQUIRED)
pkg_check_modules(GSTREAMER REQUIRED gstreamer-1.0 gstreamer-base-1.0 gstreamer-video-1.0)
pkg_check_modules(PIPEWIRE REQUIRED libpipewire-0.3)
pkg_check_modules(DBUS REQUIRED dbus-1)
pkg_check_modules(GIO REQUIRED gio-2.0 gio-unix-2.0)

add_library(myway_capture SHARED
    libmyway_capture.c
)

target_include_directories(myway_capture PRIVATE
    ${GSTREAMER_INCLUDE_DIRS}
    ${PIPEWIRE_INCLUDE_DIRS}
    ${DBUS_INCLUDE_DIRS}
    ${GIO_INCLUDE_DIRS}
)

target_link_libraries(myway_capture PRIVATE
    ${GSTREAMER_LIBRARIES}
    ${PIPEWIRE_LIBRARIES}
    ${DBUS_LIBRARIES}
    ${GIO_LIBRARIES}
)

# For ASan/UBSan in debug (Removed because they cause undefined symbol errors when loaded into non-ASan Flutter runner via FFI)
# set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -fsanitize=address,undefined")
# set(CMAKE_SHARED_LINKER_FLAGS_DEBUG "${CMAKE_SHARED_LINKER_FLAGS_DEBUG} -fsanitize=address,undefined")

install(TARGETS myway_capture DESTINATION "${CMAKE_INSTALL_PREFIX}/lib")
