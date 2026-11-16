import QtQuick
import QtTest
import "../shell/panels/Markdown.js" as Markdown

TestCase {
    name: "Markdown"

    function test_render_data() {
        return [
            { tag: "superscript", text: "x^2 and $E_{max}$", rendered: "x<sup>2</sup> and E<sub>max</sub>" },
            { tag: "symbols", text: "\\alpha \\le \\infty \\sqrt{2}", rendered: "α ≤ ∞ √(2)" },
            { tag: "unknown command", text: "\\left(", rendered: "\\left(" },
            { tag: "inline code", text: "`a_b \\pi` but \\pi", rendered: "`a_b \\pi` but π" },
            { tag: "url", text: "see https://x.org/a_b?q=x^2 now", rendered: "see https://x.org/a_b?q=x^2 now" },
            { tag: "link target", text: "[a_b](https://x.org/a_b)", rendered: "[a<sub>b</sub>](https://x.org/a_b)" },
            { tag: "fence", text: "```\na_b \\pi\n```\nc_d", rendered: "```\na_b \\pi\n```\nc<sub>d</sub>" },
            { tag: "blank", text: "  \n", rendered: "" }
        ];
    }

    function test_render(data) {
        compare(Markdown.render(data.text, 4), data.rendered);
    }
}
