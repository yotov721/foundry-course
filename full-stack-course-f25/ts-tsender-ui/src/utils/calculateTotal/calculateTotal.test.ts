import { describe, expect, it } from "vitest";
import { calculateTotal } from "./calculateTotal";

describe("calculateTotal", () => {
  it("sums comma-separated numbers", () => {
    expect(calculateTotal("100,200,300")).toBe(600);
  });

  it("sums newline-separated numbers", () => {
    expect(calculateTotal("100\n200\n300")).toBe(600);
  });

  it("sums mixed comma and newline separators", () => {
    expect(calculateTotal("100\n200,300\n400")).toBe(1000);
  });

  it("ignores extra spaces", () => {
    expect(calculateTotal(" 100 , 200 \n 300 ")).toBe(600);
  });

  it("ignores empty lines and commas", () => {
    expect(calculateTotal("100,\n,200,\n\n,300")).toBe(600);
  });

  it("ignores invalid numbers", () => {
    expect(calculateTotal("100,abc,200")).toBe(300);
  });

  it("returns 0 for empty string", () => {
    expect(calculateTotal("")).toBe(0);
  });

  it("returns 0 if all entries are invalid", () => {
    expect(calculateTotal("abc,def,\nxyz")).toBe(0);
  });

  it("parses decimal values correctly", () => {
    expect(calculateTotal("100.5,200.25")).toBeCloseTo(300.75);
  });
});
