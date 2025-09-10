import { SecuritySanitizer } from '@/lib/security/sanitizer';

describe('SecuritySanitizer', () => {
  describe('sanitizeText', () => {
    it('should remove script tags', () => {
      const input = '<script>alert("xss")</script>Hello';
      const result = SecuritySanitizer.sanitizeText(input);
      expect(result).toBe('Hello');
    });

    it('should remove javascript: protocol', () => {
      const input = 'javascript:alert("xss")';
      const result = SecuritySanitizer.sanitizeText(input);
      expect(result).toBe('alert("xss")');
    });

    it('should remove event handlers', () => {
      const input = 'onclick=alert("xss")';
      const result = SecuritySanitizer.sanitizeText(input);
      expect(result).toBe('alert("xss")');
    });
  });

  describe('validateInput', () => {
    it('should throw error for invalid input', () => {
      expect(() => SecuritySanitizer.validateInput('')).toThrow('Invalid input');
      expect(() => SecuritySanitizer.validateInput(null as any)).toThrow('Invalid input');
    });

    it('should throw error for too long input', () => {
      const longInput = 'a'.repeat(256);
      expect(() => SecuritySanitizer.validateInput(longInput)).toThrow('Input too long');
    });

    it('should return sanitized valid input', () => {
      const input = 'Valid <script>text</script>';
      const result = SecuritySanitizer.validateInput(input);
      expect(result).toBe('Valid text');
    });
  });
});