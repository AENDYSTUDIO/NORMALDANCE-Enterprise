import path from 'path';

export class PathValidator {
  static validatePath(inputPath: string, allowedDir: string): string {
    if (!inputPath || typeof inputPath !== 'string') {
      throw new Error('Invalid path');
    }

    const normalizedPath = path.normalize(inputPath);
    const resolvedPath = path.resolve(allowedDir, normalizedPath);
    const allowedDirResolved = path.resolve(allowedDir);

    if (!resolvedPath.startsWith(allowedDirResolved)) {
      throw new Error('Path traversal detected');
    }

    return resolvedPath;
  }

  static sanitizeFilename(filename: string): string {
    return filename
      .replace(/[^a-zA-Z0-9.-]/g, '_')
      .replace(/\.{2,}/g, '.')
      .substring(0, 255);
  }
}