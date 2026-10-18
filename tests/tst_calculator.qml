import QtQuick
import QtTest
import "../services/CalculatorProvider.js" as Calculator

TestCase {
    name: "Calculator"

    function test_ignoresWords() {
        verify(!Calculator.evaluate("firefox").candidate);
    }

    function test_precedenceAndFunctions() {
        compare(Calculator.evaluate("2 * (8 + 4)").result, "24");
        compare(Calculator.evaluate("= sqrt(144)").result, "12");
        compare(Calculator.evaluate("max(2, 5, 3) ^ 2").result, "25");
        compare(Calculator.evaluate("round(pi * 100) / 100").result, "3.14");
    }

    function test_hidesFloatingPointNoise() {
        compare(Calculator.evaluate("0.1 + 0.2").result, "0.3");
    }

    function test_explainsInvalidExpressions() {
        var division = Calculator.evaluate("1 / 0");
        verify(division.candidate && !division.ok);
        verify(division.error.indexOf("Division by zero") >= 0, division.error);

        var incomplete = Calculator.evaluate("=");
        verify(incomplete.candidate && !incomplete.ok);
        verify(incomplete.error.indexOf("after '='") >= 0, incomplete.error);
    }
}
