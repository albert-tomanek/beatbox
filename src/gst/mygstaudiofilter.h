#include <gst/audio/audio.h>

// Although we set the C class name to `GstAudioFilter` in the CCode tag, Vala seems to use thin macro anyway so we have to define it manually.
#define MY_GST_AUDIO_FILTER_CLASS(K) GST_AUDIO_FILTER_CLASS(K)
