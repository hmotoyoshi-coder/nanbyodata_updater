#!/usr/bin/perl


use strict;
use warnings;
use utf8;
use open ':std', ':encoding(UTF-8)';
use RDF::Trine;
use RDF::Trine::Parser;
use JSON::PP;  # JSON 生成模块
use Encode;
use Data::Dumper;

my $nando_file = shift;


my %all_nando_hash         = ();#contains all of the nando
my %parent_children_hash   = ();#contains the parent->children relation defined by memberOf and subClassOf

&read_file($nando_file, \%all_nando_hash, \%parent_children_hash);


my $json = JSON::PP->new->pretty->encode(\%all_nando_hash);
print "ALL Nando:\n";
print $json;
print "------------\n\n";

my $json2 = JSON::PP->new->pretty->encode(\%parent_children_hash);
print "ALL Parent children hiearachy:\n";
print $json2;
print "------------\n\n";



exit;

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
                if ($lang eq 'en') {
                    my $label = $o->literal_value;
                    $data{$id}{'label_en'} = utf8::is_utf8($label) ? $label : decode('UTF-8', $label);
                }
                elsif ($lang eq 'ja') {
                    my $label = $o->literal_value;
                    $data{$id}{'label_ja'} = utf8::is_utf8($label) ? $label : decode('UTF-8', $label);
                }
                elsif ($lang eq 'ja-Hira') {
                    my $label = $o->literal_value;
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
