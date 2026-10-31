import 'dart:collection';

/// In-memory cache that keeps at most [capacity] entries and evicts the
/// least recently used one when it is full.
///
/// A [LinkedHashMap] keeps its keys in insertion order, so the first key is
/// always the least recently used and the last one the most recent. Reading
/// an entry moves it to the end; both operations are O(1).
class LruCache<K, V> {
  LruCache(this.capacity) : assert(capacity > 0);

  final int capacity;
  final LinkedHashMap<K, V> _entries = LinkedHashMap<K, V>();

  int get length => _entries.length;

  /// The cached value, or null. A hit makes [key] the most recently used.
  V? get(K key) {
    final value = _entries.remove(key);
    if (value != null) _entries[key] = value;
    return value;
  }

  void put(K key, V value) {
    _entries.remove(key);
    _entries[key] = value;
    if (_entries.length > capacity) _entries.remove(_entries.keys.first);
  }
}
