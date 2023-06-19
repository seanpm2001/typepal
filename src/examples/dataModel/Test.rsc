module examples::dataModel::Test

import examples::dataModel::Syntax;
extend examples::dataModel::Checker;
extend analysis::typepal::TestFramework;

TModel dmTModelForTree(Tree pt){
    return collectAndSolve(pt, config = dmConfig());
}

TModel dmTModelFromName(str mname){
    pt = parse(#start[Program], |project://typepal/src/examples/dataModel/<mname>.dm|).top;
    return dmTModelForTree(pt);
}

value main() = dmTModelFromName("example1").messages;