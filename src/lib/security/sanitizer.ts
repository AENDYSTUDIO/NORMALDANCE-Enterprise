import DOMPurify from 'isomorphic-dompurify';

export class SecuritySanitizer {
  static sanitizeHtml(input: string): string {
    return DOMPurify.sanitize(input, {
      ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'p', 'br'],
      ALLOWED_ATTR: []
    });
  }

  static sanitizeText(input: string): string {
    return input
      .replace(/[<>]/g, '')
      .replace(/javascript:/gi, '')
      .replace(/on\w+=/gi, '')
      .trim();
  }

  static validateInput(input: string, maxLength: number = 255): string {
    if (!input || typeof input !== 'string') {
      throw new Error('Invalid input');
    }
    
    if (input.length > maxLength) {
      throw new Error(`Input too long. Max ${maxLength} characters`);
    }
    
    return this.sanitizeText(input);
  }
}