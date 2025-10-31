import { describe, it, expect } from "vitest";
import { parseSassFile } from "../src/parser/sassParser.js";

describe("SASS Parser", () => {
  describe("parseSassFile", () => {
    it("should parse simple SASS variables", async () => {
      const testContent = `
        $primary-color: #2563eb;
        $secondary-color: #1d4ed8;
        $font-family: "Inter", sans-serif;
      `;

      // Create a temporary file
      const { writeFile, unlink } = await import("node:fs/promises");
      const { tmpdir } = await import("node:os");
      const { join } = await import("node:path");
      const tempFile = join(tmpdir(), `test-${Date.now()}.scss`);

      try {
        await writeFile(tempFile, testContent, "utf-8");
        const result = await parseSassFile(tempFile);

        expect(result.variables).toHaveLength(3);
        const primaryVar = result.variables.find((v) => v.name === "primary-color");
        expect(primaryVar).toBeDefined();
        expect(primaryVar?.value).toBe("#2563eb");
        const secondaryVar = result.variables.find((v) => v.name === "secondary-color");
        expect(secondaryVar).toBeDefined();
        expect(secondaryVar?.value).toBe("#1d4ed8");
      } finally {
        await unlink(tempFile).catch(() => {});
      }
    });

    it("should parse SASS maps", async () => {
      const testContent = `
        $colors: (
          primary: #2563eb,
          secondary: #1d4ed8,
          background: #ffffff
        );
      `;

      const { writeFile, unlink } = await import("node:fs/promises");
      const { tmpdir } = await import("node:os");
      const { join } = await import("node:path");
      const tempFile = join(tmpdir(), `test-map-${Date.now()}.scss`);

      try {
        await writeFile(tempFile, testContent, "utf-8");
        const result = await parseSassFile(tempFile);

        expect(result.maps).toHaveLength(1);
        expect(result.maps[0]?.name).toBe("colors");
        expect(result.maps[0]?.entries).toHaveLength(3);
        expect(result.maps[0]?.entries.find((e) => e.key === "primary")?.value).toBe("#2563eb");
      } finally {
        await unlink(tempFile).catch(() => {});
      }
    });

    it("should handle comments correctly", async () => {
      const testContent = `
        // This is a comment
        $primary: #2563eb; // inline comment
        /* Multi-line
           comment */
        $secondary: #1d4ed8;
      `;

      const { writeFile, unlink } = await import("node:fs/promises");
      const { tmpdir } = await import("node:os");
      const { join } = await import("node:path");
      const tempFile = join(tmpdir(), `test-comments-${Date.now()}.scss`);

      try {
        await writeFile(tempFile, testContent, "utf-8");
        const result = await parseSassFile(tempFile);

        expect(result.variables).toHaveLength(2);
        expect(result.variables.find((v) => v.name === "primary")).toBeDefined();
        expect(result.variables.find((v) => v.name === "secondary")).toBeDefined();
      } finally {
        await unlink(tempFile).catch(() => {});
      }
    });

    it("should handle empty files", async () => {
      const { writeFile, unlink } = await import("node:fs/promises");
      const { tmpdir } = await import("node:os");
      const { join } = await import("node:path");
      const tempFile = join(tmpdir(), `test-empty-${Date.now()}.scss`);

      try {
        await writeFile(tempFile, "", "utf-8");
        const result = await parseSassFile(tempFile);

        expect(result.variables).toHaveLength(0);
        expect(result.maps).toHaveLength(0);
      } finally {
        await unlink(tempFile).catch(() => {});
      }
    });
  });
});

