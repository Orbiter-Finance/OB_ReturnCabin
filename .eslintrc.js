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
      "no-unused-vars": "off", // or "@typescript-eslint/no-unused-vars": "off",
      "unused-imports/no-unused-imports": "error",
      "unused-imports/no-unused-vars": [
        "warn",
        {
          vars: "all",
          varsIgnorePattern: "^_",
          args: "after-used",
          argsIgnorePattern: "^_",
        },
      ],
      "@typescript-eslint/no-unsafe-member-access": "off",
      "@typescript-eslint/no-explicit-any": "off",
      "@typescript-eslint/no-unsafe-call": "off",
      "@typescript-eslint/no-unused-vars": "off",
      "@typescript-eslint/require-await": "off",
      "@typescript-eslint/no-unsafe-return": "off",
      "@typescript-eslint/await-thenable": "off",
      "@typescript-eslint/no-unsafe-assignment": "off",
      "@typescript-eslint/no-unsafe-argument": "off",
      "@typescript-eslint/ban-types": "off",
      "@typescript-eslint/no-var-requires":"off",
      "@typescript-eslint/restrict-template-expressions": "off",
    },
  };
  