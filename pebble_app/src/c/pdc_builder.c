// pdc_builder.c
// Parses raw PDC binary data into a PdcObject (either GDrawCommandImage or
// GDrawCommandSequence), based on the magic word in the file header.
//
// Both PDC file types share this 8-byte file header (all fields little-endian):
//   Offset 0: Magic word — "PDCI" or "PDCS" (4 bytes)
//   Offset 4: Payload size in bytes (uint32_t)
//   Offset 8: Payload — GDrawCommandImage or GDrawCommandSequence blob
//
// The SDK stores both types as flat memory blobs whose layout matches the
// binary format exactly.  A malloc'd copy of the payload is therefore a valid
// pointer for all gdraw_command_image_* / gdraw_command_sequence_* APIs.

#include <pebble.h>
#include "pdc_builder.h"

#define PDC_MAGIC_SEQUENCE  "PDCS"
#define PDC_MAGIC_IMAGE     "PDCI"
#define PDC_HEADER_MAGIC    4
#define PDC_HEADER_SIZE     4   // uint32_t payload-size field
#define PDC_FILE_HEADER     (PDC_HEADER_MAGIC + PDC_HEADER_SIZE)  // 8 bytes total

// Minimum valid payload sizes
// Image:    version(1)+reserved(1)+viewbox(4)+num_cmds(2)+... = 8 bytes minimum
// Sequence: version(1)+reserved(1)+viewbox(4)+play_count(2)+frame_count(2) = 10
#define PDC_IMAGE_MIN_SIZE    8
#define PDC_SEQUENCE_MIN_SIZE 10

bool pdc_build_from_data(const uint8_t *data, size_t data_size, PdcObject *out) {
  if (!data || !out) {
    APP_LOG(APP_LOG_LEVEL_ERROR, "pdc_build: null argument");
    return false;
  }

  if (data_size < PDC_FILE_HEADER) {
    APP_LOG(APP_LOG_LEVEL_ERROR, "pdc_build: too small for header (%u bytes)", (unsigned)data_size);
    return false;
  }

  bool is_sequence = (memcmp(data, PDC_MAGIC_SEQUENCE, PDC_HEADER_MAGIC) == 0);
  bool is_image    = (memcmp(data, PDC_MAGIC_IMAGE,    PDC_HEADER_MAGIC) == 0);

  if (!is_sequence && !is_image) {
    APP_LOG(APP_LOG_LEVEL_ERROR, "pdc_build: unrecognised magic word");
    return false;
  }

  uint32_t payload_size;
  memcpy(&payload_size, data + PDC_HEADER_MAGIC, sizeof(payload_size));

  if (data_size < PDC_FILE_HEADER + payload_size) {
    APP_LOG(APP_LOG_LEVEL_ERROR, "pdc_build: truncated — need %lu, have %u",
            (unsigned long)(PDC_FILE_HEADER + payload_size), (unsigned)data_size);
    return false;
  }

  uint32_t min_size = is_image ? PDC_IMAGE_MIN_SIZE : PDC_SEQUENCE_MIN_SIZE;
  if (payload_size < min_size) {
    APP_LOG(APP_LOG_LEVEL_ERROR, "pdc_build: payload too small (%lu bytes)", (unsigned long)payload_size);
    return false;
  }

  void *blob = malloc(payload_size);
  if (!blob) {
    APP_LOG(APP_LOG_LEVEL_ERROR, "pdc_build: malloc(%lu) failed", (unsigned long)payload_size);
    return false;
  }

  memcpy(blob, data + PDC_FILE_HEADER, payload_size);

  if (is_image) {
    out->kind  = PDC_KIND_IMAGE;
    out->image = (GDrawCommandImage *)blob;
    APP_LOG(APP_LOG_LEVEL_DEBUG, "pdc_build: PDCI loaded, %lu bytes", (unsigned long)payload_size);
  } else {
    out->kind     = PDC_KIND_SEQUENCE;
    out->sequence = (GDrawCommandSequence *)blob;
    APP_LOG(APP_LOG_LEVEL_DEBUG, "pdc_build: PDCS loaded, %lu bytes, %u frames",
            (unsigned long)payload_size,
            (unsigned)gdraw_command_sequence_get_num_frames(out->sequence));
  }

  return true;
}

void pdc_destroy(PdcObject *obj) {
  if (!obj) return;
  // Both union members are heap blobs at the same address — free either.
  if (obj->image) {
    free(obj->image);
    obj->image = NULL;
  }
}

GSize pdc_get_bounds_size(const PdcObject *obj) {
  if (!obj || !obj->image) return GSizeZero;
  if (obj->kind == PDC_KIND_IMAGE) {
    return gdraw_command_image_get_bounds_size(obj->image);
  }
  return gdraw_command_sequence_get_bounds_size(obj->sequence);
}

uint32_t pdc_get_num_frames(const PdcObject *obj) {
  if (!obj || !obj->image) return 0;
  if (obj->kind == PDC_KIND_IMAGE) {
    return 1;  // images are always a single static frame
  }
  return gdraw_command_sequence_get_num_frames(obj->sequence);
}
