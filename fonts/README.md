# Bundled fonts

Static TrueType files so that every build looks the same, on any machine and in the Docker image.

| Font | Version | Weights | License |
|---|---|---|---|
| [Inter](https://rsms.me/inter/) | 4.1 | Regular, Italic, Medium, Bold, Bold Italic | SIL OFL 1.1 (`Inter-LICENSE.txt`) |
| [JetBrains Mono](https://www.jetbrains.com/lp/mono/) | 2.304 | Regular, Italic, Bold, Bold Italic | SIL OFL 1.1 (`JetBrainsMono-OFL.txt`) |

Both are used by default (body text and code). To use others, set `mainfont` / `codefont` in the
front matter and make them available to Typst.
