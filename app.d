import std.stdio;
import std.algorithm;
import std.range;
import std.string;
import std.file;
import std.math;
import std.regex;

string visitor_boilerplate = `
module ddmd.asttypename;

import ddmd.attrib;
import ddmd.aliasthis;
import ddmd.aggregate;
import ddmd.complex;
import ddmd.cond;
import ddmd.ctfeexpr;
import ddmd.dclass;
import ddmd.declaration;
import ddmd.denum;
import ddmd.dimport;
import ddmd.declaration;
import ddmd.dstruct;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.dversion;
import ddmd.expression;
import ddmd.func;
import ddmd.denum;
import ddmd.dimport;
import ddmd.dmodule;
import ddmd.mtype;
import ddmd.typinf;
import ddmd.identifier;
import ddmd.init;
import ddmd.globals;
import ddmd.doc;
import ddmd.root.rootobject;
import ddmd.statement;
import ddmd.staticassert;
import ddmd.nspace;
import ddmd.visitor;

string astTypeName(RootObject node)
{
    final switch(node.dyncast())
    {
        case DYNCAST_OBJECT:
            return "RootObject";
        case DYNCAST_EXPRESSION:
            return astTypeName(cast(Expression)node);
        case DYNCAST_DSYMBOL:
            return astTypeName(cast(Dsymbol)node);
        case DYNCAST_TYPE:
            return astTypeName(cast(Type)node);
        case DYNCAST_IDENTIFIER:
            return astTypeName(cast(Identifier)node);
        case DYNCAST_TUPLE:
            return astTypeName(cast(Tuple)node);
        case DYNCAST_PARAMETER:
            return astTypeName(cast(Parameter)node);
        case DYNCAST_STATEMENT:
            return astTypeName(cast(Statement)node);
    }
}

string astTypeName(Dsymbol node)
{
    scope tsv = new AstTypeNameVisitor;
    node.accept(tsv);
    return tsv.typeName;
}

string astTypeName(Expression node)
{
    scope tsv = new AstTypeNameVisitor;
    node.accept(tsv);
    return tsv.typeName;
}

string astTypeName(Type node)
{
    scope tsv = new AstTypeNameVisitor;
    node.accept(tsv);
    return tsv.typeName;
}

string astTypeName(Statement node)
{
    scope tsv = new AstTypeNameVisitor;
    node.accept(tsv);
    return tsv.typeName;
}

string astTypeName(Identifier node)
{
    return "Identifier";
}

string astTypeName(Initializer node)
{
    scope tsv = new AstTypeNameVisitor;
    node.accept(tsv);
    return tsv.typeName;
}

string astTypeName(Condition node)
{
    scope tsv = new AstTypeNameVisitor;
    node.accept(tsv);
    return tsv.typeName;
}

string astTypeName(TemplateParameter node)
{
    scope tsv = new AstTypeNameVisitor;
    node.accept(tsv);
    return tsv.typeName;
}

extern(C++) final class AstTypeNameVisitor : Visitor
{
    alias visit = super.visit;
public :
    string typeName;
`;

struct ASTClass
{
    string className;
    string parentName;

    string fileName;
    uint startDefinitionPos;
    uint endDefinitionPos;
}

struct Entry
{
    string nodeName;
    uint level;
    uint idx;

    uint parentIdx; /// 1 based indexing
    const(ASTClass)* _class;
    uint[] childIdxs;

    uint enumIdx;
}

Entry[] entries;

string[5] importantParents = ["Dsymbol", "Type", "Expression", "Statement", "TemplateDeclaration"];
uint[5] importantParentIdxs;

Entry[] parseDmdClassList(string input) pure
{
    Entry[] _entries;
    auto lines = input.splitLines;

    foreach (i, line; lines)
    {
        auto level = countTabs(line);
        line = line[level .. $];
        if (!line.length)
            continue;
        auto nameString = line.split(' ')[0];

        if (nameString.length)
            _entries ~= Entry(nameString, level, cast(uint) i + 1);
    }

    foreach (entryIdx; 0 .. _entries.length)
    {
        auto entryLevel = _entries[entryIdx].level;
        if (entryLevel > 1)
            foreach_reverse (i, entry; _entries[0 .. entryIdx])
            {
                if (entryLevel > entry.level)
                {
                    _entries[entryIdx].parentIdx = cast(uint) i + 1;
                    _entries[i].childIdxs ~= cast(uint) entryIdx + 1;
                    break;
                }
            }
    }

    return _entries;
}
/* TODO implement a find-dmd
string findDmdSrc()
{
// try ../dmd/src
// then ../../dmd/src

}
*/
Entry[] correlateClasses(const ASTClass[] allClasses)
{

    Entry[] result = [Entry("RootObject", 1, 0)];
    // First assign the Root-Object Descenands;

    uint lastTry;
    uint currentLevel = 1;

    for (;;)
    {
        auto c = allClasses[lastTry++];
        foreach (i, e; result)
        {
            if (e.level == currentLevel && c.parentName == e.nodeName)
            {
                auto parentIdx = cast(uint) i + 1;
                auto childIdx = cast(uint) result.length + 1;
                result ~= Entry(c.className, currentLevel + 1, childIdx,
                    parentIdx, &allClasses[lastTry - 1]);
                result[i].childIdxs ~= childIdx;
                break;
            }
        }
        if (lastTry == allClasses.length)
        {
            if (currentLevel++ < 10)
                lastTry = 0;
            else
                break;
        }
    }

    return result;
}

void main()
{
    auto allClasses = gatherClasses();
    auto correlatedClasses = correlateClasses(allClasses);
    writeln(genTypeStringVisitor(correlatedClasses));

/*
    string ch_txt = readText("ch.txt");
    entries = parseDmdClassList(ch_txt);
    writeln(genWikiSection(entries));
    writeln(gen_ch_txt(correlatedClasses));


    printVisitors();
        writeln(allClasses.length);

	foreach(c;allClasses)
	{
		c.addToConstructor("\tif(auto _s = \""~ c.className ~ "\" in _classStats) { (*_s)++; } \n\telse { _classStats[\"" ~ c.className ~ "\"] = 1; }");
	}

       writeln(rod(allClasses).map!(c => c.className));
      writeln("The DMD class hierachy has ", entries.length, " members");

    uint typeCount[6];
    foreach (i, entry; entries)
    {
        if (canFind()) writeln(entry);
        typeCount[entry.level - 1]++;
    }

    writeln(typeCount[].map!(i => cast(int)(log2(i)+0.5)));
    uint pidx;
    foreach (i, entry; entries)
    {
        if (entry.nodeName == importantParents[pidx])
            importantParentIdxs[pidx++] = cast(uint) i + 1;
    }
    pidx = 0;

    foreach (i, entry; entries)
    { // let's now compute the enumIdx
        if (importantParentIdxs[].canFind(i))
        {
            entry.enumIdx = 1 << pidx++;
            continue;
        }
        else
        {
            Entry ipe = entry;
            while (ipe.level > 2)
            {
                ipe = entries[ipe.parentIdx - 1];
            }

        }

    }
*/
}

string genTypeStringVisitor(Entry[] _entries)
{
    string result;

    result ~= "\n" ~ (visitor_boilerplate);
    foreach (entry; _entries)
    {
        //FIXME hack as long as TypeDeduced and CTFEExp are without
        // visitor-support don't generate visit methods for them
        if (entry.nodeName != "TypeDeduced" && entry.nodeName != "CTFEExp")
        {
            result ~= "\n";
            result ~= "\n" ~ ("    override void visit(" ~ entry.nodeName ~ " node)");
            result ~= "\n" ~ ("    {");
            result ~= "\n" ~ ("        typeName = \"" ~ entry.nodeName ~ "\";");
            result ~= "\n" ~ ("    }");
        }
    }

    result ~= "\n}\n";

    return result;
}

struct BracePosition
{
    uint beginPos;
    uint endPos;

    T opCast(T : bool)()
    {
        return endPos != 0;
    }
}

BracePosition nextBraceAndMatchingEndBrace(const string text, const uint startPos) pure @safe nothrow
{
    uint beginPos = startPos;
    // search for first opening brace starting at startPos;
    while (beginPos < text.length && text[beginPos++] != '{')
    {
    }

    // if we are not at the end, meaning a brace has been found
    if (beginPos != text.length)
    {
        uint endPos = beginPos;
        uint balanceCounter = 1;
        while (endPos < text.length && balanceCounter)
        {
            char c = text[endPos++];

            if (c == '{')
                balanceCounter++;
            if (c == '}')
                balanceCounter--;

        }
        // we found a balanced pair of braces
        if (!balanceCounter)
        {
            return BracePosition(beginPos - 1, endPos - 1);
        }
    }

    return BracePosition.init;
}

uint countTabs(const string line) pure
{
    int numTabs;
    while (line.length && line[numTabs] == '\t')
    {
        ++numTabs;
    }
    return numTabs;
}

ASTClass[] gatherClasses()
{
    auto r = regex(
        `extern \(C\+\+\) (?:final class|abstract class|class) ([a-zA-Z]*) \: ([a-zA-Z]*)`);

    ASTClass[] classes;
    foreach (string filename; dirEntries("src/", "*.d", SpanMode.shallow))
    {
        auto content = readText(filename);
        foreach (m; matchAll(content, r).filter!(m => m.captures[2] != "Visitor"
                && m.captures[2] != "StoppableVisitor"))
        {
            auto bp = nextBraceAndMatchingEndBrace(content, cast(uint)(m.front.ptr - content.ptr));
            classes ~= ASTClass(m.captures[1], m.captures[2], filename, bp.beginPos,
                bp.endPos);
        }
    }

    return classes;
}

const(ASTClass[]) rod(const ASTClass[] allClasses)
{
    return allClasses.filter!(c => c.parentName == "RootObject").array;
}

void addToConstructor(ASTClass _class, string code)
{
    auto fileText = readText(_class.fileName);
    auto def = fileText[_class.startDefinitionPos .. _class.endDefinitionPos];
    auto r = regex(`extern \(D\) this`);
    auto mf = matchFirst(def, r);
    if (mf.empty)
    {
        writeln("no match on ", _class.className);
        return;
    }
    auto constructorBounds = nextBraceAndMatchingEndBrace(fileText,
        cast(uint)(mf.front.ptr - fileText.ptr));
    auto wFile = fileText[0 .. constructorBounds.beginPos + 1] ~ "\n" ~ code ~ "\n" ~ fileText[
        constructorBounds.beginPos + 2 .. $];
    std.file.write(_class.fileName, wFile);
}

string[] visitorNames()
{
    string[] result;

    auto r = regex(
        `extern \(C\+\+\) (?:final class|abstract class|class) ([a-zA-Z]*) \: ([a-zA-Z]*)`);

    foreach (string filename; dirEntries("src/", "*.d", SpanMode.shallow))
    {
        foreach (m; matchAll(readText(filename), r).filter!(
                m => m.captures[2] == "Visitor" || m.captures[2] == "StoppableVisitor"))
        {
            result ~= m.captures[1];
        }
    }

    return result;
}

string genDot(Entry[] correlatedClasses)
{
    string result = "digraph AST {\n";

    foreach (cc; correlatedClasses[12 .. $]) // starts at 12 to skip the direct children of root-object.
    {
        result ~= "\t" ~ correlatedClasses[cc.parentIdx - 1].nodeName ~ " -> " ~ cc.nodeName ~ "\n";
    }
    result ~= "}";

    return result;
}

string writeTabs(const uint n) pure
{
    string result;

    foreach (_; 0 .. n)
    {
        result ~= "\t";
    }

    return result;
}

string writeStars(const uint n) pure
{
    string result;

    foreach (_; 0 .. n)
    {
        result ~= "*";
    }

    return result;
}

uint recursiveNumberOfChildren(const Entry[] correlatedClasses, const uint idx)
{
    uint result;
    auto e = correlatedClasses[idx];
    result = cast(uint) e.childIdxs.length;

    foreach (cidx; e.childIdxs)
    {
        result += recursiveNumberOfChildren(correlatedClasses, cidx - 1);
    }

    return result;
}

string genWikiSection(const Entry[] _entries, const uint idx = 0)
{
    string result;
    auto e = _entries[idx];

    result = writeStars(e.level) ~ " " ~ e.nodeName ~ "\n";
    foreach (cidx; e.childIdxs)
    {
        result ~= genWikiSection(_entries, cidx - 1);
        if (idx == 0) result ~= "\n";
    }
   
    return result;
}

string gen_ch_txt(const Entry[] correlatedClasses, const uint idx = 0)
{
    string result;
    auto e = correlatedClasses[idx];

    result = writeTabs(e.level) ~ e.nodeName ~ "\n";

    // auto sortedIdxs = e.childIdxs[].dup.sort!((a, b) => (correlatedClasses[a - 1].childIdxs.length > correlatedClasses[b - 1].childIdxs.length));
       auto sortedIdxs = e.childIdxs[].dup.sort!((a,b) => (recursiveNumberOfChildren(correlatedClasses, a - 1) > recursiveNumberOfChildren(correlatedClasses, b - 1)));
    //   auto sortedIdxs = e.childIdxs[].dup.sort!((a,b) => (correlatedClasses[a - 1].nodeName[0] > correlatedClasses[b - 1].nodeName[0]));

    foreach (cidx; sortedIdxs)
    {
        result ~= gen_ch_txt(correlatedClasses, cidx - 1);
    }

    return result;
}
