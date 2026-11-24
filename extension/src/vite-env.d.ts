/// <reference types="vite/client" />
declare module 'virtual:native-strings' {
  const strings: { tr: Record<string, string>; en: Record<string, string> };
  export default strings;
}
