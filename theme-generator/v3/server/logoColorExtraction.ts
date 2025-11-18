import sharp from 'sharp';
import { getSaturation, isNearGrayscale, rgbToHex } from './colorExtraction';

/**
 * Logo color extraction from screenshot
 * Samples a header/logo region near the top of the image for brand color hints
 */

interface ColorBucket {
  count: number;
  r: number;
  g: number;
  b: number;
  saturationSum: number;
}

/**
 * Extracts a dominant saturated color from the top region of a screenshot
 * Samples the top 200-300px region and clusters pixels to find dominant colors
 */
export async function extractLogoColor(screenshotBase64: string): Promise<string | undefined> {
  try {
    // Handle data URL format: data:image/png;base64,<data>
    let base64Data: string;
    if (screenshotBase64.startsWith('data:')) {
      // Extract base64 portion after comma
      const commaIndex = screenshotBase64.indexOf(',');
      if (commaIndex === -1) {
        console.warn('[analyzer] Invalid data URL format for logo extraction');
        return undefined;
      }
      base64Data = screenshotBase64.substring(commaIndex + 1);
    } else {
      // Assume it's already base64
      base64Data = screenshotBase64;
    }
    
    // Decode base64 to buffer
    const buffer = Buffer.from(base64Data, 'base64');
    
    // Validate buffer is not empty
    if (buffer.length === 0) {
      console.warn('[analyzer] Empty buffer for logo extraction');
      return undefined;
    }
    
    // Get image metadata - explicitly tell Sharp it's PNG
    let metadata;
    try {
      // Try to process as PNG explicitly
      metadata = await sharp(buffer, { failOn: 'none' }).png().metadata();
    } catch (error) {
      // If Sharp can't read it, it might be corrupted or wrong format
      console.warn('[analyzer] Sharp cannot read screenshot format:', error instanceof Error ? error.message : 'Unknown error');
      return undefined;
    }
    
    // Validate we got valid metadata
    if (!metadata || !metadata.width || !metadata.height) {
      console.warn('[analyzer] Invalid image metadata from screenshot');
      return undefined;
    }
    const width = metadata.width || 1280;
    const height = metadata.height || 720;
    
    // Sample top region (top 200-300px, or top 30% if image is smaller)
    const sampleHeight = Math.min(300, Math.max(200, Math.floor(height * 0.3)));
    
    // Extract region: full width, top sampleHeight pixels
    // Ensure we don't exceed image dimensions
    const extractHeight = Math.min(sampleHeight, height);
    const extractWidth = width;
    
    let region: Buffer;
    try {
      region = await sharp(buffer, { failOn: 'none' })
        .png()
        .extract({
          left: 0,
          top: 0,
          width: extractWidth,
          height: extractHeight
        })
        .raw()
        .toBuffer();
    } catch (error) {
      console.warn('[analyzer] Failed to extract logo region:', error instanceof Error ? error.message : 'Unknown error');
      return undefined;
    }
    
    // Cluster pixels into buckets (simple quantization)
    const buckets = new Map<string, ColorBucket>();
    const pixelCount = extractWidth * extractHeight;
    
    // Sample pixels (every 4th pixel for performance)
    const step = Math.max(1, Math.floor(pixelCount / 10000));
    
    for (let i = 0; i < region.length; i += 4 * step) {
      const r = region[i];
      const g = region[i + 1];
      const b = region[i + 2];
      const alpha = region[i + 3];
      
      // Skip transparent or very transparent pixels
      if (alpha < 128) continue;
      
      // Quantize to reduce color space (16 levels per channel)
      const quantizedR = Math.floor(r / 16);
      const quantizedG = Math.floor(g / 16);
      const quantizedB = Math.floor(b / 16);
      const key = `${quantizedR}-${quantizedG}-${quantizedB}`;
      
      let bucket = buckets.get(key);
      if (!bucket) {
        bucket = { count: 0, r: 0, g: 0, b: 0, saturationSum: 0 };
        buckets.set(key, bucket);
      }
      
      bucket.count += 1;
      bucket.r += r;
      bucket.g += g;
      bucket.b += b;
      
      // Calculate saturation
      const maxChannel = Math.max(r, g, b);
      const minChannel = Math.min(r, g, b);
      const saturation = maxChannel === 0 ? 0 : (maxChannel - minChannel) / maxChannel;
      bucket.saturationSum += saturation;
    }
    
    if (buckets.size === 0) {
      return undefined;
    }
    
    // Convert buckets to colors and filter
    const colors = Array.from(buckets.values())
      .map(bucket => {
        const avgR = Math.round(bucket.r / bucket.count);
        const avgG = Math.round(bucket.g / bucket.count);
        const avgB = Math.round(bucket.b / bucket.count);
        const avgSaturation = bucket.saturationSum / bucket.count;
        
        const hex = rgbToHex(`rgb(${avgR}, ${avgG}, ${avgB})`);
        
        return {
          hex,
          saturation: avgSaturation,
          count: bucket.count,
          brightness: (avgR * 299 + avgG * 587 + avgB * 114) / 1000 / 255
        };
      })
      .filter(color => {
        // Filter out near-grayscale colors
        if (isNearGrayscale(color.hex)) return false;
        
        // Filter out very low saturation colors
        if (color.saturation < 0.15) return false;
        
        // Filter out very dark or very light colors (likely backgrounds/text)
        if (color.brightness < 0.1 || color.brightness > 0.9) return false;
        
        return true;
      })
      .sort((a, b) => {
        // Sort by saturation first, then by frequency
        if (Math.abs(a.saturation - b.saturation) > 0.05) {
          return b.saturation - a.saturation;
        }
        return b.count - a.count;
      });
    
    // Return the most dominant saturated color
    if (colors.length > 0) {
      return colors[0].hex;
    }
    
    return undefined;
  } catch (error) {
    console.warn('[analyzer] Logo color extraction failed:', error);
    return undefined;
  }
}
