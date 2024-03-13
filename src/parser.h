
typedef struct {
  void *parents;
  void *value;
  const void* allocator;
  const char* file_path;
  void* buf_set;
} ParseState;