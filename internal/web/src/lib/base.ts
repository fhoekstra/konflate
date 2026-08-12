// Runtime base path injected by the Go server into index.html. Empty string
// means konflate is served at the root path.
export const basePath: string = (window as any).KONFLATE_BASE_PATH ?? '';
