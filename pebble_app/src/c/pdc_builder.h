// pdc_builder.h
// Utilities for constructing drawable PDC objects from raw binary data.
// Handles both PDCI (image) and PDCS (sequence) file formats.

#pragma once
#include <pebble.h>

// ---------------------------------------------------------------------------
// Tagged wrapper — holds either a GDrawCommandImage or GDrawCommandSequence.
// ---------------------------------------------------------------------------

typedef enum {
  PDC_KIND_IMAGE,    // Static image  — use gdraw_command_image_*
  PDC_KIND_SEQUENCE, // Animated seq  — use gdraw_command_sequence_* / frame_*
} PdcKind;

typedef struct {
  PdcKind kind;
  union {
    GDrawCommandImage    *image;
    GDrawCommandSequence *sequence;
  };
} PdcObject;

// ---------------------------------------------------------------------------
// API
// ---------------------------------------------------------------------------

// Build a PdcObject from raw PDC binary data (PDCI or PDCS file).
//
// @param data      Pointer to the raw PDC bytes.
// @param data_size Total number of valid bytes in `data`.
// @param out       Filled on success with kind + pointer.
//
// @return true on success. The caller must call pdc_destroy(out) when done.
bool pdc_build_from_data(const uint8_t *data, size_t data_size, PdcObject *out);

// Free memory allocated by pdc_build_from_data().
void pdc_destroy(PdcObject *obj);

// Convenience: get the bounding box size regardless of kind.
GSize pdc_get_bounds_size(const PdcObject *obj);

// Convenience: get the number of animation frames.
// Returns 1 for images (always static).
uint32_t pdc_get_num_frames(const PdcObject *obj);
