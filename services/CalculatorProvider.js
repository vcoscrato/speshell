.pragma library

function tokenize(source) {
    var tokens = [];
    var index = 0;
    while (index < source.length) {
        var rest = source.substring(index);
        var whitespace = rest.match(/^\s+/);
        if (whitespace) {
            index += whitespace[0].length;
            continue;
        }
        var number = rest.match(/^(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?/i);
        if (number) {
            tokens.push({ type: "number", value: Number(number[0]) });
            index += number[0].length;
            continue;
        }
        var identifier = rest.match(/^[a-z][a-z0-9_]*/i);
        if (identifier) {
            tokens.push({ type: "identifier", value: identifier[0].toLowerCase() });
            index += identifier[0].length;
            continue;
        }
        var ch = source[index];
        if ("+-*/%^(),".indexOf(ch) >= 0) {
            tokens.push({ type: ch, value: ch });
            index++;
            continue;
        }
        throw new Error("Unexpected character '" + ch + "'.");
    }
    tokens.push({ type: "end", value: "" });
    return tokens;
}

function peek(state) {
    return state.tokens[state.index];
}

function take(state, type) {
    if (peek(state).type !== type)
        return null;
    return state.tokens[state.index++];
}

function expect(state, type, label) {
    var token = take(state, type);
    if (!token)
        throw new Error("Expected " + (label || type) + ".");
    return token;
}

function applyFunction(name, args) {
    if (name === "sqrt" && args.length === 1) return Math.sqrt(args[0]);
    if (name === "abs" && args.length === 1) return Math.abs(args[0]);
    if (name === "round" && args.length === 1) return Math.round(args[0]);
    if (name === "floor" && args.length === 1) return Math.floor(args[0]);
    if (name === "ceil" && args.length === 1) return Math.ceil(args[0]);
    if (name === "sin" && args.length === 1) return Math.sin(args[0]);
    if (name === "cos" && args.length === 1) return Math.cos(args[0]);
    if (name === "tan" && args.length === 1) return Math.tan(args[0]);
    if (name === "log" && args.length === 1) return Math.log(args[0]) / Math.LN10;
    if (name === "ln" && args.length === 1) return Math.log(args[0]);
    if (name === "min" && args.length > 0) return Math.min.apply(Math, args);
    if (name === "max" && args.length > 0) return Math.max.apply(Math, args);
    throw new Error("Unknown function or wrong argument count: " + name + ".");
}

function parsePrimary(state) {
    var number = take(state, "number");
    if (number)
        return number.value;
    if (take(state, "(")) {
        var grouped = parseExpression(state);
        expect(state, ")", "')'");
        return grouped;
    }
    var identifier = take(state, "identifier");
    if (identifier) {
        if (identifier.value === "pi") return Math.PI;
        if (identifier.value === "e") return Math.E;
        expect(state, "(", "'(' after " + identifier.value);
        var args = [];
        if (peek(state).type !== ")") {
            args.push(parseExpression(state));
            while (take(state, ","))
                args.push(parseExpression(state));
        }
        expect(state, ")", "')'");
        return applyFunction(identifier.value, args);
    }
    throw new Error("Expected a number, constant, function, or parenthesized expression.");
}

function parseUnary(state) {
    if (take(state, "+")) return parseUnary(state);
    if (take(state, "-")) return -parseUnary(state);
    return parsePrimary(state);
}

function parsePower(state) {
    var value = parseUnary(state);
    if (take(state, "^"))
        value = Math.pow(value, parsePower(state));
    return value;
}

function parseTerm(state) {
    var value = parsePower(state);
    while (true) {
        if (take(state, "*")) {
            value *= parsePower(state);
        } else if (take(state, "/")) {
            var divisor = parsePower(state);
            if (divisor === 0) throw new Error("Division by zero.");
            value /= divisor;
        } else if (take(state, "%")) {
            var modulus = parsePower(state);
            if (modulus === 0) throw new Error("Modulo by zero.");
            value %= modulus;
        } else {
            return value;
        }
    }
}

function parseExpression(state) {
    var value = parseTerm(state);
    while (true) {
        if (take(state, "+")) value += parseTerm(state);
        else if (take(state, "-")) value -= parseTerm(state);
        else return value;
    }
}

function format(value) {
    if (Math.abs(value) < 1e-14)
        value = 0;
    if (Math.floor(value) === value && Math.abs(value) < 1e15)
        return String(value);
    return Number(value.toPrecision(12)).toString();
}

function isCandidate(query) {
    var value = String(query || "").trim();
    if (value.indexOf("=") === 0)
        return true;
    if (!/[0-9]/.test(value))
        return false;
    if (!/^(?:[0-9eE.+\-*/%^(),\s]|pi|sqrt|abs|round|floor|ceil|sin|cos|tan|log|ln|min|max)+$/i.test(value))
        return false;
    return /[+\-*/%^()]|(?:sqrt|abs|round|floor|ceil|sin|cos|tan|log|ln|min|max)\s*\(/i.test(value);
}

function evaluate(query) {
    var raw = String(query || "").trim();
    var explicit = raw.indexOf("=") === 0;
    var expression = explicit ? raw.substring(1).trim() : raw;
    if (!isCandidate(raw))
        return { candidate: false, ok: false, expression: expression, result: "", error: "" };
    if (expression === "")
        return { candidate: true, ok: false, expression: expression, result: "", error: "Enter an expression after '='." };
    try {
        var state = { tokens: tokenize(expression), index: 0 };
        var value = parseExpression(state);
        expect(state, "end", "the end of the expression");
        if (!isFinite(value) || isNaN(value))
            throw new Error("The expression has no finite result.");
        return { candidate: true, ok: true, expression: expression, result: format(value), error: "" };
    } catch (calculationError) {
        return {
            candidate: true,
            ok: false,
            expression: expression,
            result: "",
            error: String(calculationError.message || calculationError)
        };
    }
}
