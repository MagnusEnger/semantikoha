# Placeholder for script to enrich triplestore with data from Lexvo

SELECT DISTINCT ?lang WHERE {
  GRAPH ?g { ?s <http://purl.org/dc/terms/language> ?lang . }
}
