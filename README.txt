SemantiKoha - exploring Linked Data in Koha

* GOALS

The short term goals of this project are to: 

- Harvest bibliographich records from Koha, convert them to RDF and 
  store the RDF in a triplestore. 
- Create proof-of-concept scripts to enhance the converted 
  bibliographic data in the triplestore with data from other sources. 
- Enrich the Koha OPAC with the data from the triplestore. 

The long term goal is to hopefully prove that we do not need the MARC 
data, but that we can do everything MARC could do, and a whole lot 
more, with Semantic Data/RDF/Linked Data. 

* DEMO

A live Koha demo reflectig the current state of the scripts in this 
repository is available here:

http://semantikoha.libriotech.no/

This demo works as follows:

1. Records are harvested regularly with the oai_harvester.rb script 
from http://github.com/digibib/marc2rdf and turned into RDF, using the 
default NORMARC-to-RDF mapping. The resulting records are stored in a 
triplestore here:

http://data.libriotech.no/semantikoha/

This triplestore is currently running ARC2 
( https://github.com/semsol/arc2 ), but this may change in the future. 

2. Scripts in the scripts/ directory are run, with the triplestore as 
their target. Currently, arc2-client.pl picks out URIs for persons 
from the data converted from MARC, that have not yet been enhanced. 
The name associated with the URI is used to query the SPARQL endpoint 
of the Norwegian project "Rådata nå!". When a match is found, RDF data 
from Rådata nå! containing "sameAs" pointers to further data for the 
same person are loaded into the triplestore and new "sameAs"-relations 
added through this process are explored and added to the triplestore 
iteratively. 

In time, more original sources will be added, alongside Rådata nå!.

3. Data from the triplestore are displayed in Koha in two different 
ways:

3a. Detail pages

When a detial page in the OPAC is displayed, a small box containing 
data from the triplestore is inserted into the page with AJAX 
techniques. 

The following snippet of JavaScript code is included in the opacuserjs 
syspref in Koha:

jQuery(document).ready(function () {
  var id = $(".unapi-id").attr("title");
  $.get("/cgi-bin/koha/opac-view.pl", { id: id },
    function(html){
      $("#bibliodescriptions").prepend(html);
    }
  ); 
});

This piece of code looks for an element with class unapi-id in the 
page, and extracts an identifier for the record being viewed, which 
has this form:

koha:biblionumber:x

where x is the biblionumber of the record being displayed. This string 
is then used to construct an AJAX-request which is sent to the 
opac-view.pl script:

/cgi-bin/koha/opac-view.pl?id=koha:biblionumber:x

opac-view.pl then extracts the actual biblionumber from the string it 
gets passed, and uses that to construct the URI for the record in 
question. This URI is then used to retrieve information about the 
record from the triplestore. This information is formatted with 
templates/rec_insert.tt and the resulting HTML-snippet is returned to 
the JavaScript-caller and inserted into the HTML of the record detail 
page. 

Currently only names and pictures of authors are retrieved from the 
triplestore to be included in the detail view, but this will of course 
be expanded. Names and pictures of authors are linked to the 
opac-view.pl script, with the URI of the person in question as the 
identifier:

/cgi-bin/koha/opac-view.pl?uri=<uri>

3b. opac-view.pl 

opac-view.pl takes one of two arguments: "id" as described above, or 
"uri":

Given a URI as argument, relevant information about that URI is 
fetched from the triplestore and displayed on the page. Currently 
pictures and Influenced/Influenced by is shown for persons, along 
with a simple table displaying the results of this generic query:

SELECT * WHERE {
  GRAPH ?g { <uri> ?p ?o . }
}

Objects that are of type URI are made clickable so that it is possible 
to explore relations in the data. 

* Shortcuts

At this stage, this work is a proof of concept, so ease of development 
wins over doing things properly. To that end I am in fact running 
opac-view.pl on a separate server from the Koha installation, and just 
making it appear as a page in the OPAC with the following Apache 
config:

RewriteEngine on
RewriteRule /cgi-bin/koha/opac-view.pl http://data.libriotech.no/cgi-bin/test.pl [P]

So opac-view.pl is in fact the same script as cgi-bin/test.pl in the 
current repository. (I'll probably rename test.pl to opac-view.pl one 
of these days...)

* TODO

There is *a lot* of work to do in how opac-view.pl displays relevant 
info for a URI. 

- What information to display should be configured in the triplestore, 
  not hardcoded
- opac-view.pl should check the rdfs:type of a URI and then act 
  appropriately for each type we have said we are interested in, based 
  on configuration-data stored in the triplestore

* SEE ALSO

- http://wiki.koha-community.org/wiki/Linked_Data_RFC
- http://github.com/digibib/marc2rdf
- https://github.com/MagnusEnger/marc2rdf
- http://www.bibsys.no/files/out/linked_data/autreg/index.html
