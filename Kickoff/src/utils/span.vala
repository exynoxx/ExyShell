namespace Utils {
    public class Span<T> {
        private unowned T[] data;
        private int offset;
        private int len;
        
        public Span(T[] source, int offset = 0, int length = -1) {
            this.data = source;
            this.offset = offset;
            this.len = (length < 0) ? source.length - offset : length;
        }
        
        public int length {
            get { return len; }
        }
        
        public T get(int index) {
            return data[offset + index];
        }
        
        public void set(int index, T value) {
            data[offset + index] = value;
        }
        
        public Span<T> slice(int start, int length = -1) {
            int slice_len = (length < 0) ? (len - start) : length;
            return new Span<T>.from_span(this, start, slice_len);
        }
        
        private Span.from_span(Span<T> parent, int start, int length) {
            this.data = parent.data;
            this.offset = parent.offset + start;
            this.len = length;
        }
    }
}