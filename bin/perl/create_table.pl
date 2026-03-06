#!/usr/bin/perl

### description ###
# tool for creating following mysql table data which used by treeview module for nanbyodata(nando):
# - nando descendant list table
# - nando upstream trace table 
# - nando hierarchy table 
# - nando panel table

###  version history ###
#
# version 20250926: 1. use ttl data https://nanbyodata.jp/download/2025-08-26/nando.ttl
#                   2. use RDF::Trine to retrieve every entry from ttl
#                   3. use NANDO:0000001 as the root entry
#
 
use strict;
use warnings;
use utf8;
use open ':std', ':encoding(UTF-8)';  
use RDF::Trine;
use RDF::Trine::Parser;
use Encode;
use Data::Dumper;
use JSON;
use DBI;


if (@ARGV != 2) {
    die "Usage: $0 <ttl data file name> <user defined data version>\n";
}

my $nando_file = shift;

our $ONTOVERSION = shift;

my $ROOT_ALL = 'NANDO:0000001';

our $DB_NAME = $ENV{'DB_NAME'};
our $DB_USER = $ENV{'DB_USER'};
our $DB_PASS = $ENV{'DB_PASS'};
our $DB_HOST = $ENV{'DB_HOST'};
our $DB_PORT = $ENV{'DB_PORT'};

my $dbh = DBI->connect("DBI:mysql:dbname=$DB_NAME;host=$DB_HOST;port=$DB_PORT","$DB_USER","$DB_PASS") or die "$!\n Error: failed to connect to DB.\n";
$dbh->do("set names utf8");


my %all_nando_hash		   = ();#contains all of the nando

my %parent_children_hash   = ();#contains the parent->children relation defined by memberOf and subClassOf

# read info from data file
&read_file($nando_file, \%all_nando_hash, \%parent_children_hash);


# output db table.
&insert_all_panel_to_db(\%all_nando_hash, \%parent_children_hash, $ONTOVERSION, $dbh);
&insert_all_hierarchy_to_db(\%parent_children_hash, $ONTOVERSION, $dbh);
&insert_all_upstream_trace_to_db(\%all_nando_hash, \%parent_children_hash, $ONTOVERSION, $dbh);


$dbh->disconnect;
exit;



sub insert_all_panel_to_db{
	my ($all_nando_hash_ref, $parent_children_hash_ref, $OntoVersion, $db) = @_;

	my $sth = $db->prepare("INSERT INTO nanbyodata_nando_panel(OntoVersion,OntoID,OntoName,OntoNameJa,OntoDescendantNum) VALUES (?,?,?,?,?)");

	# get all node start from $ROOT_ALL. 
	my %total_hash = ();
	get_all_descendant($ROOT_ALL, $parent_children_hash_ref, \%total_hash);
	$total_hash{$ROOT_ALL} = 1;

	foreach my $root_id (sort keys %total_hash ) {
		my %tmp_hash = ();
 		get_all_descendant($root_id, $parent_children_hash_ref, \%tmp_hash);
        my @tmp = keys %tmp_hash;
		$all_nando_hash_ref->{$root_id}{'num_of_descendant'} = scalar @tmp;
		$sth->execute(	$OntoVersion, 
						$root_id, 
						$all_nando_hash_ref->{$root_id}{'name_en'},
						$all_nando_hash_ref->{$root_id}{'name_ja'},
						scalar @tmp
		);
	}
	$sth->finish;			
}


sub insert_upstream_trace_to_db{

	my($OntoVersion, $db,$nando_id,$trace_ref_en,$trace_ref_ja) = @_;	

	my $json_data_en;
	if($trace_ref_en){
		$json_data_en = encode_json($trace_ref_en);
	}
	my $json_data_ja;
	if($trace_ref_ja){
		$json_data_ja = encode_json($trace_ref_ja);
	}
	my $sth = $db->prepare("INSERT INTO nanbyodata_nando_panel_upstream_trace(nando_id,trace_en,trace_ja) VALUES (?,?,?)");
	eval {
    	$sth->execute($nando_id, $json_data_en, $json_data_ja);
	};
	if ($@) {
    	# $@ is set if eval dies
    	if ($DBI::err && $DBI::err == 1062) {  # 1062 = MySQL duplicate entry error
        	warn "Duplicate entry for id=$nando_id, skipping insert\n";
    	} else {
        	die "Database error: $DBI::errstr\n";  # rethrow if it's not a duplicate
    	}
	}
	$sth->finish;
}

sub _create_upstream_json{

	my ($nando_id, $all_upstream_trace_list_ref, $all_nando_hash_ref, $upstream_trace_en_ref, $upstream_trace_ja_ref) = @_;

	foreach my $upstream_trace (sort { $b cmp $a } @{$all_upstream_trace_list_ref}){

		my @trace_nodes = split(',', $upstream_trace);
	
		next if($trace_nodes[0] ne $ROOT_ALL);

		my $current = $upstream_trace_en_ref;
		for(my $i=0; $i < scalar @trace_nodes; $i++){
			my $spot_nando_id = $trace_nodes[$i];
			my $spot_name = $spot_nando_id;
			if($all_nando_hash_ref->{$spot_nando_id}{'name_en'}){
				$spot_name = $all_nando_hash_ref->{$spot_nando_id}{'name_en'};
			}
			my $spotnum = $all_nando_hash_ref->{$spot_nando_id}{'num_of_descendant'};
			my $spot_key = $spot_nando_id . "--" . $spotnum . "--" . $spot_name;
		
			if($spot_nando_id eq $nando_id){
				$current->{$spot_key} = 1;
			}elsif(exists $current->{$spot_key}){
				$current = \%{$current->{$spot_key}};
			}else{
				$current->{$spot_key} = ();
				$current = \%{$current->{$spot_key}};
			}
		}

		$current = $upstream_trace_ja_ref;
		for(my $i=0; $i < scalar @trace_nodes; $i++){
			my $spot_nando_id = $trace_nodes[$i]; 
			my $spot_name = $spot_nando_id;
			if($all_nando_hash_ref->{$spot_nando_id}{'name_ja'}){
				$spot_name = $all_nando_hash_ref->{$spot_nando_id}{'name_ja'};
			}elsif($all_nando_hash_ref->{$spot_nando_id}{'name_en'}){
				$spot_name = $all_nando_hash_ref->{$spot_nando_id}{'name_en'};
			}

			my $spotnum = $all_nando_hash_ref->{$spot_nando_id}{'num_of_descendant'};
			my $spot_key = $spot_nando_id . "--" . $spotnum . "--" . $spot_name;
			
			if($spot_nando_id eq $nando_id){
				$current->{$spot_key} = 1;
			}elsif(exists $current->{$spot_key}){
				$current = \%{$current->{$spot_key}};
			}else{
				$current->{$spot_key} = ();
				$current = \%{$current->{$spot_key}};
			}
		}
	}
}


sub _find_and_slice {
    my ($item, @list) = @_;
   
    # Find the index of the item in the list
    for my $i (0..$#list) {
        if ($list[$i] eq $item) {
            # Return the subset of the list from start to this item
            return @list[0..$i];
        }
    }

    # If the item is not found, return an empty list
    return ();
}


sub insert_all_upstream_trace_to_db{

	
	my ($all_nando_hash_ref, $parent_children_hash_ref, $OntoVersion, $db) = @_;
	
	my @total_substram_trace_arr = ();
	retrieve_all_substream_trace($ROOT_ALL, $ROOT_ALL, $parent_children_hash_ref, \@total_substram_trace_arr);

    my %total_hash = ();
    get_all_descendant($ROOT_ALL, $parent_children_hash_ref, \%total_hash);
    &insert_upstream_trace_to_db($OntoVersion, $db,$ROOT_ALL,\(),\());

	foreach my $node_id (sort keys %total_hash){

		my @all_upstream_trace = ();
		foreach my $downstream_trace (@total_substram_trace_arr){
			my $index = index($downstream_trace, $node_id);
			if($index >= 0){
				my @t = split(',', $downstream_trace);
				my @t_slice = &_find_and_slice($node_id, @t);
				if(scalar @t_slice > 0){
					my $upstream_trace = join(',', @t_slice);
					push(@all_upstream_trace, $upstream_trace);
				}
			}
		}
		
		if(scalar @all_upstream_trace == 0){
			print STDERR "Interrupted due to not found upstream trace for node[".$node_id."]\n";
			exit;
		}
		my %upstream_trace_en = ();
		my %upstream_trace_ja = ();
		&_create_upstream_json($node_id, \@all_upstream_trace, $all_nando_hash_ref, \%upstream_trace_en, \%upstream_trace_ja);
		&insert_upstream_trace_to_db($OntoVersion, $db,$node_id,\%upstream_trace_en,\%upstream_trace_ja);
	}
}


###
# create the nanbyodata_nando_panel_hierarchy table.
###
sub insert_all_hierarchy_to_db{

	my ($parent_children_hash_ref, $OntoVersion, $db) = @_;

	#print "insert all child - parent hierarchy\n";

	my $sth = $db->prepare("INSERT INTO nanbyodata_nando_panel_hierarchy(nando_id,parent_nando_id) VALUES (?,?)");
	
	foreach my $parent_node_id (sort keys %{$parent_children_hash_ref}){
		foreach my $child_node_id (sort @{$parent_children_hash_ref->{$parent_node_id}}){
			$sth->execute($child_node_id, $parent_node_id);
		}
	}
	$sth->finish;
}




###
# get all downstream trace
###
sub retrieve_all_substream_trace{
	my ($parent_nando_id, $trace_str, $parent_children_hash_ref, $output_arr_ref) = @_;
	if(!(exists $parent_children_hash_ref->{$parent_nando_id})){
		if($parent_nando_id ne $trace_str){
			push(@$output_arr_ref, $trace_str);
			return 1;
		}else{
			return 0;
		}
	}
	my $cnt = 0;
	my @downstream_arr = @{$parent_children_hash_ref->{$parent_nando_id}};
	foreach my $downstream_nando_id (@downstream_arr){
		my @tmp = split(",", $trace_str);
		if(grep {$_ eq $downstream_nando_id} @tmp){
			next;
		}
		$cnt = $cnt + &retrieve_all_substream_trace($downstream_nando_id, $trace_str . "," . $downstream_nando_id, $parent_children_hash_ref, $output_arr_ref);
	}	

	if($cnt == 0 ){
		if($parent_nando_id ne $trace_str){
			push @$output_arr_ref,$trace_str;
			return 1;
		}else{
			return 0;
		}
	}	 
}

###
# for input nando id, get all of the descendant nando id
###
sub get_all_descendant {

	my ($root_nando_id, $parent_children_hash_ref, $out_hash_ref) = @_;

	my @substram_trace_arr = ();

	retrieve_all_substream_trace($root_nando_id, $root_nando_id, $parent_children_hash_ref, \@substram_trace_arr);
	foreach my $trace (@substram_trace_arr){
		my @trace_nodes =  split(',', $trace);
		foreach my $trace_node_id (@trace_nodes){
			if($trace_node_id ne $root_nando_id){
				$out_hash_ref->{$trace_node_id} = 1;
			}
		} 
	}
}



###
# retrieve following information from input file
# - all nando information(name_en,name_ja) 
# - the nando hierarchy information defined by subClassOf.
# - skip the obsolete item
###
sub read_file{
	
	my ($file, $all_nando_hash_ref, $parent_children_hash_ref) = @_;

	open my $fh, "<:encoding(UTF-8):crlf", $file or die "Cannot open $file: $!";
	
	my $model = RDF::Trine::Model->new;
	my $parser = RDF::Trine::Parser->new("turtle");
	$parser->parse_file_into_model("http://nanbyodata.jp/ontology/nando/", $fh, $model);

	my %data;
	my $iter = $model->get_statements(undef, undef, undef);
	while (my $st = $iter->next) {
		my $s = $st->subject->uri_value;
		my $p = $st->predicate->uri_value;
		my $o = $st->object;

		next unless $s =~ /NANDO_(\d{7})/;
		my $id = $1;
		$data{$id}{'subClassOf'} //= [];

		# dcterms:identifier
		if ($p eq 'http://purl.org/dc/terms/identifier') {
			my $nando_id = $o->literal_value;
			$data{$id}{'nando_id'} = $nando_id;
		}
		# rdfs:subClassOf
		elsif ($p eq 'http://www.w3.org/2000/01/rdf-schema#subClassOf' && $o->is_resource) {
			if ($o->uri =~ /NANDO_(\d{7})$/) {
				my $subclassof = "NANDO:$1";
				push @{ $data{$id}{'subClassOf'} }, $subclassof;
			}
		}
		# rdfs:label
		elsif ($p eq 'http://www.w3.org/2000/01/rdf-schema#label') {
			if($o->is_literal){
				my $lang = $o->literal_value_language // '';
				my $label = $o->literal_value;
				if ($lang eq 'en') {
					$data{$id}{'label_en'} = utf8::is_utf8($label) ? $label : decode('UTF-8', $label);	
				}
				elsif ($lang eq 'ja') {
					$data{$id}{'label_ja'} = utf8::is_utf8($label) ? $label : decode('UTF-8', $label);  
				}
				elsif ($lang eq 'ja-Hira') {
					$data{$id}{'label_ja_hira'} = utf8::is_utf8($label) ? $label : decode('UTF-8', $label); 
				}
			}
		}
	}

	foreach my $id (keys %data){
		my $nando_id = $data{$id}{"nando_id"};
		my $label_en = exists $data{$id}{"label_en"} ? $data{$id}{"label_en"} : $nando_id;
		my $label_ja = exists $data{$id}{"label_ja"} ? $data{$id}{"label_ja"} : $nando_id;
		my @parent_list = @{ $data{$id}{'subClassOf'} };

		next if ($label_en =~ /obsolete/i || $label_ja =~ /obsolete/i);

		$all_nando_hash_ref->{$nando_id}{'name_en'} = $label_en;
		$all_nando_hash_ref->{$nando_id}{'name_ja'} = $label_ja;

		for my $real_nando_id_parent (@parent_list){
			if(!exists $parent_children_hash_ref->{$real_nando_id_parent}){
				my @t = ();
				$parent_children_hash_ref->{$real_nando_id_parent} = \@t;
			}
			push(@{$parent_children_hash_ref->{$real_nando_id_parent}}, $nando_id);
		}
	}
}
