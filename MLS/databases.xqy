xquery version "1.0-ml";

(: Attempts to get a list of all the databases on the server.
:)

declare namespace prop="http://marklogic.com/xdmp/property";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare option xdmp:mapping "false";

declare variable $EXCLUDE as xs:string*
        := ("App-Services", "Fab", "Last-Login", "Modules", "Schemas", "Security", "Triggers");

for $id in xdmp:databases()
let $name := xdmp:database-name($id)
where not($name = $EXCLUDE)
order by $name
return
  $name
