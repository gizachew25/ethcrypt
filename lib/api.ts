import { NextResponse } from "next/server";
import { ZodError } from "zod";

export type ApiError = { error: string; details?: unknown };

export function ok<T>(data: T, status = 200) {
  return NextResponse.json(data, { status });
}

export function fail(message: string, status = 400, details?: unknown) {
  return NextResponse.json<ApiError>({ error: message, details }, { status });
}

export function handleZod(err: unknown) {
  if (err instanceof ZodError) {
    return fail("Validation failed", 422, err.flatten().fieldErrors);
  }
  console.error(err);
  return fail("Something went wrong", 500);
}
