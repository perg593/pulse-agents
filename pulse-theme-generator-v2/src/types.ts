export interface CssVarEvidence {
  type: "css-var";
  selector: string;
  property: string;
  value: string;
  href: string | null;
  important?: boolean;
}

export interface CssPropertyEvidence {
  type: "css-prop";
  selector: string;
  property: string;
  value: string;
  href: string | null;
  important?: boolean;
}

export interface ComputedEvidence {
  type: "computed";
  selector: string;
  property: string;
  value: string;
}

export interface LogoEvidence {
  type: "logo";
  source: string;
  method: "image" | "svg";
  value: string;
  note?: string;
}

export interface DerivedEvidence {
  type: "derived";
  note: string;
}

export type Evidence = CssVarEvidence | CssPropertyEvidence | ComputedEvidence | LogoEvidence | DerivedEvidence;

export interface RawFinding {
  name: string;
  normalizedName: string;
  category: "color" | "font" | "spacing" | "radius" | "shadow" | "z-index" | "unknown";
  value: string;
  sources: Evidence[];
}

export interface TokenMapping {
  id: string;
  value: string;
  confidence: number;
  evidence: Evidence[];
  fallbackReason?: string | null;
  notes?: string | null;
}

export interface ThemeReport {
  [tokenId: string]: TokenMapping;
}

export interface ThemeJson {
  [group: string]: Record<string, unknown>;
}

export interface ExtractionTarget {
  url: string;
  maxPages?: number;
  scheme?: "light" | "dark";
}

export interface ExtractOptions {
  target: ExtractionTarget;
  allowAdditionalPages?: string[];
}
