xquery version "1.0-ml";

(: Attempts to get a list of the URIs in the specified database. If an xs:dateTime or
   xs:dayTimeDuration is given as $since; only the URIs of documents updated since that
   date are returned. The $since feature relies on "maintain last modified" being "true"
   in the database configuration.
:)

declare namespace prop="http://marklogic.com/xdmp/property";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare option xdmp:mapping "false";

declare variable $database as xs:string? := xdmp:get-request-field("database");
declare variable $sincestr as xs:string? := xdmp:get-request-field("since");
declare variable $since as xs:dateTime?
  := if (empty($sincestr))
     then ()
     else if ($sincestr castable as xs:dateTime)
          then xs:dateTime($sincestr)
          else if ($sincestr castable as xs:dayTimeDuration)
               then current-dateTime() - xs:dayTimeDuration($sincestr)
               else if ($sincestr castable as xs:date)
                    then xs:dateTime(concat($sincestr, "T00:00:00"))
                    else error(xs:QName("BADSINCE"), concat("Not a valid since: ", $sincestr));

if (empty($database))
then
  error(xs:QName("NODATABASE"), "You must specify the database to backup")
else
  let $evalopts
    := <options xmlns="xdmp:eval">
         <database>{xdmp:database($database)}</database>
       </options>
  let $sincequery := "declare namespace prop='http://marklogic.com/xdmp/property';
                      declare variable $lmprop as xs:QName := xs:QName('prop:last-modified');
                      declare variable $since as xs:dateTime external;
                      try {
                        for $doc in cts:search(collection(),
                                        cts:properties-query(
                                            cts:element-range-query($lmprop,'>',$since)))
                        return
                          xdmp:node-uri($doc)
                      } catch ($e) {
                        for $doc in collection()
                        let $uri := xdmp:node-uri($doc)
                        let $lm := xs:dateTime(xdmp:document-get-properties($uri, $lmprop))
                        where $lm > $since
                        return
                          xdmp:node-uri($doc)
                      }"
  let $uriquery := "try {
                     cts:uris()[not(ends-with(., '/'))]
                   } catch ($e) {
                     for $doc in collection()
                     return
                       xdmp:node-uri($doc)
                   }"
  return
    if (empty($since))
    then
      xdmp:eval($uriquery, (), $evalopts)
    else
      xdmp:eval($sincequery, (xs:QName("since"), $since), $evalopts)
