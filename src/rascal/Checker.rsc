module rascal::Checker

import IO;
import String;
import util::Benchmark;

import lang::rascal::\syntax::Rascal;
import Type;
import lang::rascal::types::ConvertType;
import lang::rascal::types::AbstractType;

extend typepal::TypePal;
extend typepal::TestFramework;

data AType 
     = rascalType(Symbol symbol)
     ;
data IdRole
    = moduleId()
    | functionId()
    | variableId()
    | formalId()
    | labelId()
    ;

data PathLabel
    = importLabel()
    | extendLabel()
    ;

data Vis
    = publicVis()
    | privateVis()
    ;

data Modifier
    = javaModifier()
    | testModifier()
    | defaultModifier()
    ;

data DefInfo(Vis vis = publicVis());

str AType2String(rascalType(Symbol s)) = prettyPrintType(s);

bool isSubType(rascalType(Symbol s1), rascalType(Symbol s2), FRModel frm) = subtype(s1, s2);
AType getLUB(rascalType(t1), rascalType(t2), FRModel frm) = rascalType(lub(t1, t2));

set[Symbol] numericTypes = { Symbol::\int(), Symbol::\real(), Symbol::\rat(), Symbol::\num() };

// Rascal-specific defines

Tree declare(FunctionDeclaration fd, Tree scope, FRBuilder frb){

}

// Check the types of Rascal literals
void collect(Literal l:(Literal)`<IntegerLiteral il>`, Tree scope, FRBuilder frb){
    frb.atomicFact(il, rascalType(Symbol::\int()));
}

void collect(Literal l:(Literal)`<RealLiteral rl>`, Tree scope, FRBuilder frb){
    frb.atomicFact(l, rascalType(Symbol::\real()));
}

void collect(Literal l:(Literal)`<BooleanLiteral bl>`, Tree scope, FRBuilder frb){
    frb.atomicFact(l, rascalType(Symbol::\bool()));
 }

void collect(Literal l:(Literal)`<DateTimeLiteral dtl>`, Tree scope, FRBuilder frb){
    frb.atomicFact(l, rascalType(Symbol::\datetime()));
}

void collect(Literal l:(Literal)`<RationalLiteral rl>`, Tree scope, FRBuilder frb){
    frb.atomicFact(l, rascalType(Symbol::\rat()));
}

//void collect(Literal l:(Literal)`<RegExpLiteral rl>`, Configuration c) {

void collect(Literal l:(Literal)`<StringLiteral sl>`, Tree scope, FRBuilder frb){
    frb.atomicFact(l, rascalType(Symbol::\str()));
}

void collect(Literal l:(Literal)`<LocationLiteral ll>`, Tree scope, FRBuilder frb){
    frb.atomicFact(l, rascalType(Symbol::\loc()));
}

// A few expressions

void collect(exp: (Expression) `<QualifiedName name>`, Tree scope, FRBuilder frb){
    frb.use(scope, name, {variableId(), formalId()});
}

void collect(exp: (Expression) `{ <Statement+ statements> }`, Tree scope, FRBuilder frb){
    stats = [ stat | Statement stat <- statements ];
    frb.calculate("non-empty block", exp, stats,
        AType() { return typeof(stats[-1]); }
        );
}

void collect(exp: (Expression) `<Expression exp1> + <Expression exp2>`, Tree scope, FRBuilder frb){
    frb.calculate("addition", exp, [exp1, exp2], 
        AType() {
            if(rascalType(t1) := typeof(exp1) && rascalType(t2) := typeof(exp2)){
                if(t1 in numericTypes && t2 in numericTypes){
                   return rascalType(lub(t1, t2));
                }
                switch([t1, t2]){
                    case [\list(e1), x]: return \list(e2) := x ? rascalType(\list(lub(e1, e2))) : rascalType(\list(lub(e1, x)));
                    case [\set(e1), x]: return \set(e2) := x ? rascalType(\set(lub(e1, e2))) : rascalType(\set(lub(e1, x)));
                    case [\map(e1a, e2a), \map(e1b, e2b)]: return rascalType(\map(lub(e1a,e1b), lub(e2a,e2b)));
                    case [\tuple(e1), \tuple(e2)]: return rascalType(\tuple(lub(e1, e2)));
                    case [\str(), \str()]: return rascalType(\str());
                    case [\loc(), \str()]: return rascalType(Symbol::\loc());       
                }
                if(\list(e2) := t2){
                    return rascalType(\list(lub(t1, e2)));
                }
                if(\set(e2) := t2){
                    return rascalType(\set(lub(t1, e2)));
                }
             }   
             reportError(exp, "No version of `+` is applicable", [exp1, exp2]);    
      }); 
}

void collect(exp: (Expression) `[ <{Expression ","}* elements0> ]`, Tree scope, FRBuilder frb){
    elms = [ e | Expression e <- elements0 ];
    if(isEmpty(elms)){
        frb.atomicFact(exp, rascalType(\list(Symbol::\void())));    // TODO: some trigger missing: we cannot use the calculate only
    } else {
        frb.calculate("list expression", exp, elms,
            AType() {
                return rascalType(\list((Symbol::\void() | lub(it, t) | elm <- elms, rascalType(t) := typeof(elm))));
            });
        }
}

void collect(exp: (Expression) `{ <{Expression ","}* elements0> }`, Tree scope, FRBuilder frb){
    elms = [ e | Expression e <- elements0 ];
    if(isEmpty(elms)){
        frb.atomicFact(exp, rascalType(\set(Symbol::\void())));
    } else {
        frb.calculate("set expression", exp, elms,
            AType() {
                return rascalType(\set((Symbol::\void() | lub(it, t) | elm <- elms, rascalType(t) := typeof(elm))));
            });
    }
}

void collect(exp: (Expression) `<Pattern pat> := <Expression expression>`, Tree scope, FRBuilder frb){
    frb.fact(exp, [expression], AType(){ return typeof(expression); });
    frb.require("match operator", exp, [pat, expression],
        () { equal(typeof(expression), typeof(pat), onError(exp, "Incompatible type in match"));
             fact(pat, typeof(expression));
           });
}

// A few patterns

void collect(Pattern pat:(Literal)`<IntegerLiteral il>`, Tree scope, FRBuilder frb){
    frb.atomicFact(pat, rascalType(Symbol::\int()));
}

void collect(Patternpat:(Literal)`<RealLiteral rl>`, Tree scope, FRBuilder frb){
    frb.atomicFact(pat, rascalType(Symbol::\real()));
}

void collect(Patternpat:(Literal)`<BooleanLiteral bl>`, Tree scope, FRBuilder frb){
    frb.atomicFact(pat, rascalType(Symbol::\bool()));
 }

void collect(Patternpat:(Literal)`<DateTimeLiteral dtl>`, Tree scope, FRBuilder frb){
    frb.atomicFact(pat, rascalType(Symbol::\datetime()));
}

void collect(Patternpat:(Literal)`<RationalLiteral rl>`, Tree scope, FRBuilder frb){
    frb.atomicFact(pat, rascalType(Symbol::\rat()));
}

//void collect(Literalpat:(Literal)`<RegExpLiteral rl>`, Configuration c) {

void collect(Patternpat:(Literal)`<StringLiteral sl>`, Tree scope, FRBuilder frb){
    frb.atomicFact(pat, rascalType(Symbol::\str()));
}

void collect(Patternpat:(Literal)`<LocationLiteral ll>`, Tree scope, FRBuilder frb){
    frb.atomicFact(pat, rascalType(Symbol::\loc()));
}
            
void collect(Pattern pat: (Pattern) `<QualifiedName name>`, Tree scope, FRBuilder frb){
    tau = frb.newTypeVar(scope);
    frb.atomicFact(name, tau);
}

Tree define(Pattern pat: (Pattern) `<Type tp> <Name name>`, Tree scope, FRBuilder frb){
    declaredType = rascalType(convertType(tp));
    frb.atomicFact(pat, declaredType);
    return scope;
}


void collect(pat: (Pattern) `[ <{Pattern ","}* elements0> ]`, Tree scope, FRBuilder frb){
    elms = [ p | Pattern p <- elements0 ];
    if(isEmpty(elms)){
        frb.atomicFact(pat, rascalType(\list(Symbol::\void())));    // TODO: some trigger missing: we cannot use the calculate only
    } else {
        frb.calculate("list pattern", pat, elms,
            AType() {
                return rascalType(\list((Symbol::\void() | lub(it, t) | elm <- elms, rascalType(t) := typeof(elm))));
            });
        }
}

void collect(pat: (Pattern) `{ <{Pattern ","}* elements0> }`, Tree scope, FRBuilder frb){
    elms = [ p | Pattern p <- elements0 ];
    if(isEmpty(elms)){
        frb.atomicFact(pat, rascalType(\set(Symbol::\void())));    // TODO: some trigger missing: we cannot use the calculate only
    } else {
        frb.calculate("set pattern", pat, elms,
            AType() {
                return rascalType(\set((Symbol::\void() | lub(it, t) | elm <- elms, rascalType(t) := typeof(elm))));
            });
        }
}

// A few statements

void collect(stat: (Statement) `<Expression expression>;`,  Tree scope, FRBuilder frb){
    frb.fact(stat, [expression], AType(){ return typeof(expression); });
}

Tree define(stat: (Statement) `<QualifiedName name> = <Statement statement>`, Tree scope, FRBuilder frb){
    frb.fact(stat, [statement], AType(){ return typeof(statement); });
    frb.define(scope, "<name>", variableId(), name, defLub([statement], AType(){ return typeof(statement); }));
    frb.require("assignment to variable `<name>`", stat, [name, statement],
                () { subtype(typeof(statement), typeof(name), onError(stat, "Incompatible type in assignment to variable `<name>`")); });  
    
    return scope;
}

Tree define(stat: (Statement) `<Type tp> <{Variable ","}+ variables>;`, Tree scope, FRBuilder frb){
    declaredType = rascalType(convertType(tp));
    frb.atomicFact(stat, declaredType);
    for(v <- variables){
        frb.define(scope, "<v.name>", variableId(), v, defType(declaredType));
        if(v is initialized){
            frb.require("initialization of variable `<v.name>`", v, [v.initial],
                () { subtype(typeof(v.initial), declaredType, onError(v, "Incompatible type in initialization of `<v.name>`")); });  
        }
    }
    return scope;
}

// ----  Examples & Tests --------------------------------

private Expression sampleExpression(str name) = parse(#Expression, |home:///git/TypePal/src/rascal/<name>.rsc-exp|);
private Module sampleModule(str name) = parse(#Module, |home:///git/TypePal/src/rascal/<name>.rsc|);

set[Message] validateModule(str name) {
    startTime = cpuTime();
    b = sampleModule(name);
    afterParseTime = cpuTime();
    m = extractFRModel(b, newFRBuilder());
    afterExtractTime = cpuTime();
    msgs = validate(m, isSubType=isSubType, getLUB=getLUB).messages;
    afterValidateTime = cpuTime();
    println("parse:    <(afterParseTime - startTime)/1000000> ms
            'extract:  <(afterExtractTime - afterParseTime)/1000000> ms
            'validate: <(afterValidateTime - afterExtractTime)/1000000> ms
            'total:    <(afterValidateTime - startTime)/1000000> ms");
    return msgs;
}

set[Message] validateExpression(str name) {
    b = sampleExpression(name);
    m = extractFRModel(b, newFRBuilder());
    return validate(m, isSubType=isSubType, getLUB=getLUB).messages;
}


void testExp() {
    runTests(|project://TypePal/src/rascal/exp.ttl|, #Expression, isSubType=isSubType, getLUB=getLUB);
}