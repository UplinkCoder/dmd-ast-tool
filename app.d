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
import ddmd.doc;
import ddmd.root.rootobject;
import ddmd.statement;
import ddmd.staticassert;
import ddmd.visitor;

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
    // populated after populate was called
    uint parentIdx;
    uint numberOfChildren;

    uint importantParentIdx;
    uint enumIdx;
}

Entry[] entries;

string[5] importantParents = ["Dsymbol","Type","Expression","Statement","TemplateDeclaration"];
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

void main() {
    string ch_txt = readText("ch.txt");
    auto lines = ch_txt.splitLines; 

    foreach(i,line;lines)
    {
        auto level = countTabs(line);
        line = line[level .. $];
        if (!line.length) continue;
        auto nameString = line.split(' ')[0];

	if(nameString.length)
            entries ~= Entry(level, nameString);
    }

    writeln("The DMD class hierachy has ", entries.length, " members");

    foreach(i; 0 .. entries.length)
        populate(cast(uint)i);


    uint typeCount[6];
    foreach(i, entry;entries)
    {
     //   if (canFind()) writeln(entry);
        typeCount[entry.level-1]++;
    }
   writeln(genTypeStringVisitor());

//   writeln(typeCount/*[].map!(i => cast(int)(log2(i)+0.5))*/);
    uint pidx;
    foreach(i, entry;entries)
    {
     if (entry.nodeName == importantParents[pidx])   
        importantParentIdxs[pidx++] = cast(uint)i;       
    }
    pidx = 0;
    
    foreach(i, entry;entries)
    {   // let's now compute the enumIdx
        if (importantParentIdxs[].canFind(i))
        { 
            entry.enumIdx = 1 << pidx++;
            continue;
        }
        else
        {
            Entry ipe = entry;  
            while(ipe.level > 2)
            {
                ipe = entries[ipe.parentIdx];
            }
            
        }
        
    }
}

string genTypeStringVisitor()
{
   string result;

   result ~= "\n" ~ (visitor_boilerplate);
   foreach(entry;entries)
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

void populate(uint entryIdx)
{
        auto entryLevel = entries[entryIdx].level;
        if(entryLevel > 1) foreach_reverse(i, entry; entries[0 .. entryIdx])
        {
            if(entryLevel > entry.level)
            {
                entries[entryIdx].parentIdx = cast(uint)i;
                ++entries[i].numberOfChildren;
		return ;
            }
        }

	return ;
}

uint countTabs(ref string line)
{
    int numTabs;
    while(line.length && line[numTabs] == '\t')  {++numTabs;}
    return numTabs;
}

