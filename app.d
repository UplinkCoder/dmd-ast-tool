import std.stdio;
import std.algorithm;
import std.range;
import std.string;
import std.file;
import std.math;

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
import ddmd.visitor;


string astTypeName(RootObject node)
{
    switch(node.dyncast())
    {
        case DYNCAST_IDENTIFIER:
            return astTypeName(cast(Identifier)node);
        case DYNCAST_DSYMBOL:
            return astTypeName(cast(Dsymbol)node);
        case DYNCAST_TYPE:
            return astTypeName(cast(Type)node);
        case DYNCAST_EXPRESSION:
            return astTypeName(cast(Expression)node);
        default : assert(0, "don't know this DYNCAST");
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

struct Entry
{
    uint level; 
    string nodeName;
    uint idx; ///starts at 1
    // populated after populate was called
    uint parentIdx; /// 1 based indexing
    uint numberOfChildren;

    uint enumIdx;
}

Entry[] entries;

string[5] importantParents = ["Dsymbol", "Type", "Expression", "Statement", "TemplateDeclaration"];
uint[5] importantParentIdxs;
/*ClassDeclaration[] extractClassDeclarations(string code)
{
 // looks like:
 // extern (C++) final class DollarExp : IdentifierExp
 // OR 
 // extern (C++) abstract class Expression : RootObject
 // OR
 // extern (C++) class IdentifierExp : Expression
    

}*/
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
            _entries ~= Entry(level, nameString, cast(uint) i);
    }

    return _entries;
}

void main()
{
    string ch_txt = readText("ch.txt");
    entries = parseDmdClassList(ch_txt);
    populate(&entries);

    writeln("The DMD class hierachy has ", entries.length, " members");

    uint typeCount[6];
    foreach (i, entry; entries)
    {
        //   if (canFind()) writeln(entry);
        typeCount[entry.level - 1]++;
    }
    //writeln(genTypeStringVisitor());

    //   writeln(typeCount/*[].map!(i => cast(int)(log2(i)+0.5))*/);
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
}

string genTypeStringVisitor()
{
    string result;

    result ~= "\n" ~ (visitor_boilerplate);
    foreach (entry; entries)
    {
        {
            result ~= "\n";
            result ~= "\n" ~ ("    override void visit(" ~ entry.nodeName ~ " node)");
            result ~= "\n" ~ ("    {");
            result ~= "\n" ~ ("        typeName = \"" ~ entry.nodeName ~ "\";");
            result ~= "\n" ~ ("    }");
        }
    }

    return result;
}

void populate(Entry[]* _entries)
{
    const Entry[] c_entries = *_entries;
    foreach (entryIdx; 0 .. _entries.length)
    {
        auto entryLevel = c_entries[entryIdx].level;
        if (entryLevel > 1)
            foreach_reverse (i, entry; c_entries[0 .. entryIdx])
            {
                if (entryLevel > entry.level)
                {
                    (*_entries)[entryIdx].parentIdx = cast(uint) i + 1;
                    ++(*_entries)[i].numberOfChildren;
                    break;
                }
            }
    }
    return;
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

void GatherDefinitionLocations()
{
    // we need to match the regex "extern (C++)" * "class" \s some_name_in_list *

    //	extern(C++) 
}
