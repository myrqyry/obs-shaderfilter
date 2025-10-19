// Minimal compatibility shim for obs/util/circlebuf.h
// This provides a very small circular buffer API used only by the plugin's audio capture.
#pragma once

#include <vector>
#include <cstddef>
#include <cstring>

struct circlebuf {
    std::vector<unsigned char> buf;
    size_t head = 0;
    size_t tail = 0;
    size_t size = 0;
};

static inline void circlebuf_init(struct circlebuf *c)
{
    if (c) {
        c->buf.clear();
        c->head = c->tail = c->size = 0;
    }
}

static inline void circlebuf_reserve(struct circlebuf *c, size_t bytes)
{
    if (!c) return;
    c->buf.resize(bytes);
    c->head = c->tail = 0;
    c->size = 0;
}

static inline void circlebuf_free(struct circlebuf *c)
{
    if (!c) return;
    c->buf.clear();
    c->head = c->tail = c->size = 0;
}

// push_back appends raw data to the buffer (bytes points to data, len is byte length)
static inline void circlebuf_push_back(struct circlebuf *c, const void *bytes, size_t len)
{
    if (!c || !bytes || len == 0) return;
    if (c->buf.empty()) return; // not reserved

    size_t capacity = c->buf.size();
    // If len larger than capacity, keep only the last 'capacity' bytes
    const unsigned char *src = (const unsigned char*)bytes;
    if (len >= capacity) {
        // copy last capacity bytes
        src += (len - capacity);
        len = capacity;
        c->head = 0;
        c->tail = 0;
        c->size = 0;
    }

    size_t first_chunk = std::min(len, capacity - c->tail);
    std::memcpy(&c->buf[c->tail], src, first_chunk);
    if (len > first_chunk) {
        std::memcpy(&c->buf[0], src + first_chunk, len - first_chunk);
        c->tail = (len - first_chunk);
    } else {
        c->tail = (c->tail + first_chunk) % capacity;
    }

    c->size = std::min(capacity, c->size + len);
    if (c->size == capacity) {
        // advance head when we have overwritten
        c->head = c->tail;
    }
}

// Read len bytes into dest; assumes enough data is available (caller checks size)
static inline void circlebuf_read(struct circlebuf *c, void *dest, size_t len)
{
    if (!c || !dest || len == 0) return;
    if (c->buf.empty()) return;

    size_t capacity = c->buf.size();
    size_t to_read = std::min(len, c->size);
    unsigned char *d = (unsigned char*)dest;

    size_t first_chunk = std::min(to_read, capacity - c->head);
    std::memcpy(d, &c->buf[c->head], first_chunk);
    if (to_read > first_chunk) {
        std::memcpy(d + first_chunk, &c->buf[0], to_read - first_chunk);
        c->head = (to_read - first_chunk);
    } else {
        c->head = (c->head + first_chunk) % capacity;
    }

    c->size -= to_read;
}
