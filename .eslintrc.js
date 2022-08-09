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
      "prettier"
    ],
    extends: [
      "plugin:@typescript-eslint/recommended",
      "plugin:@typescript-eslint/recommended-requiring-type-checking",
      "plugin:prettier/recommended"
    ],
    rules: {
      "@typescript-eslint/no-unsafe-member-access":"off",
      "@typescript-eslint/no-unsafe-return":"off",
      "@typescript-eslint/no-unsafe-assignment":"off",
      "@typescript-eslint/no-unsafe-call":"off",
      "@typescript-eslint/no-unsafe-argument":"off",
      "@typescript-eslint/no-var-requires":"off"
    },
  };
  