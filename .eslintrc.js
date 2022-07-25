module.exports = {
    env: {
      browser: false,
      node: true,
    },
    parser: "@typescript-eslint/parser",
    parserOptions: {
      project: "tsconfig.json",
      sourceType: "module",
    },
    plugins: [
      "unused-imports",
      "@typescript-eslint",
      "eslint-plugin-import",
      "simple-import-sort",
    ],
    extends: [
      "plugin:@typescript-eslint/recommended",
      "plugin:@typescript-eslint/recommended-requiring-type-checking",
      "prettier",
    ],
    rules: {},
  };
  