#! /usr/bin/env python
#
# Run ./collapse_cleanup.py file-in filetype(nexus or fasta) then optional sequence_cleaner flags
# Lauren Chan 06 July 2013

from Bio import SeqIO
from Bio import Seq
import sys

def sequence_cleaner(filename, filetype, min_length=0, por_n=100):
    if "nex" in filetype:
        print "Infile is in Nexus format"
        dat = SeqIO.parse(filename, "nexus")
    elif "fa" in filetype:
        print "Infile is in fasta format"
        dat = SeqIO.parse(filename, "fasta")
    else:
        print "Unclear what filetype this is... quitting"
        exit(0)
    
### POACHED FROM SEQUENCE_CLEANER.PY ###
    #create our hash table to add the sequences
    sequences={}
 
    #Using the biopython fasta parse we can read our fasta input
    for seq_record in dat:
        #Take the current sequence
        sequence=str(seq_record.seq).upper()
        #Check if the current sequence is according to the user parameters
        if (len(sequence)>=min_length and (float(sequence.count("N"))/float(len(sequence)))*100<=por_n):
        # If the sequence passed in the test "is It clean?" and It isnt in the hash table, 
        # the sequence and Its id are going to be in the hash
            if sequence not in sequences:
                sequences[sequence]=seq_record.id
       # If It is already in the hash table, We're just gonna concatenate the ID of the 
       # current sequence to  another one that is already in the hash table
            else:
                sequences[sequence]+="*"+seq_record.id
 
    #Write the clean sequences
    #Create a file in the same directory where you ran this script
    clear_filename="clear_"+filename+".fa"
    output_file=open(clear_filename,"w+")
    #Just Read the Hash Table and write on the file as a fasta format
    for sequence in sequences:
            output_file.write(">"+sequences[sequence]+"\n"+sequence+"\n")
    output_file.close()
 
    print "CLEAN!!!\n%s holds your haplotypes.\n" % clear_filename
### -- END POACHING -- ###

    print "Now we'll clean up the taxon labels\n"
    outroot = raw_input("Root for outfiles: ")
    make_nex = raw_input("Make a Nexus file? y/n: ")
    reduce_hapnames(clear_filename, outroot, make_nex)
    

def reduce_hapnames(infile, outroot, make_nex):
    tosort = SeqIO.parse(infile, "fasta")  # Get data from fasta
    sorted_names = sorted(x.name for x in tosort)
    record_index = SeqIO.index(infile, "fasta")
    records = (record_index[id] for id in sorted_names) 
    
    # Create output files... need to decide how to name these.
    fastaout = open(outroot+".haps.fasta", "w+")
    namesout = open(outroot+".hapkey.txt","w+")    
    
    for index, dat in enumerate(records):   # For each instance:
        thenames = dat.name                 # Get the long name
        seqname = thenames.split('*')       # Split by *
        seqcount = len(seqname)             # Count the number of indiv with that haplotype
    
        fastaout.write('>%s_%i\n%s\n' % (seqname[0], seqcount, dat.seq))
        namesout.write('%i %s_%i: %s\n' % (index, seqname[0], seqcount, seqname))
    
    # Dimensions of the datamatrix
    n = index + 1
    seqlen = len(dat.seq)   
    
    # Close out the files we're writing
    fastaout.close()
    namesout.close()

    # Whether or not we make a nexus file
    if "y" in make_nex or "Y" in make_nex:
        write_nexus(outroot, n, seqlen, infile)
        print "Generating Nexus matrix with %i seqs and %i basebairs" % (n, seqlen)
    else:
        print "Not generating a Nexus file"


# Writing the nexus file
def write_nexus(outroot, ntax, nchar, infile):
    cleanedfasta = SeqIO.parse(outroot+".haps.fasta", "fasta")
    nexusout = open(outroot+".haps.nex", "w")
    
    nexusout.write('#NEXUS\n')
    nexusout.write('[Converted from %s using reduce_convert.py, by LMC July 06, 2013]\n' % infile)
    nexusout.write('[%s holds the haplotype designations]\n\n' % (outroot+'.hapkey.txt'))
    
    nexusout.write('Begin DATA;\n')
    nexusout.write('\tdimensions ntax=%i nchar=%i;\n' % (ntax, nchar))
    nexusout.write('\tformat datatype=DNA missing=? gap=-;\n\tmatrix\n')
    for i in cleanedfasta:
        nexusout.write('\t\t%s\t\t%s\n' % (i.name, i.seq))
    nexusout.write(';\nEND;')

# Running of script   
userParameters=sys.argv[1:]
 
try:
    if len(userParameters)==1:
        sequence_cleaner(userParameters[0], "fasta")
    elif len(userParameters)==2:
        sequence_cleaner(userParameters[0], userParameters[1])
    elif len(userParameters)==3:
        sequence_cleaner(userParameters[0], userParameters[1], float(userParameters[2]))
    elif len(userParameters)==4:
        sequence_cleaner(userParameters[0], userParameters[1], float(userParameters[2]),float(userParameters[3]))
    else:
        print "There is a problem!"
except:
    print "There is a problem!"
    exit(0)