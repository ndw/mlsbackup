xquery version "1.0-ml";

import module namespace admin = "http://marklogic.com/xdmp/admin"
       at "/MarkLogic/admin.xqy";

import module namespace sec="http://marklogic.com/xdmp/security"
       at "/MarkLogic/security.xqy";

declare namespace prop="http://marklogic.com/xdmp/property";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare variable $database as xs:unsignedLong := xdmp:database(xdmp:get-request-field("database"));
declare variable $evalopts
   := <options xmlns="xdmp:eval">
        <database>{$database}</database>
      </options>;

declare option xdmp:mapping "false";
declare option xdmp:output "method=xml";
declare option xdmp:output "indent=no";

declare function local:backup($uri as xs:string) {
  let $doc  := xdmp:eval("declare variable $uri as xs:string external; doc($uri)",
                         (xs:QName("uri"), $uri), $evalopts)
  let $coll := xdmp:eval("declare variable $uri as xs:string external; xdmp:document-get-collections($uri)",
                         (xs:QName("uri"), $uri), $evalopts)
  let $perm := xdmp:eval("declare variable $uri as xs:string external; xdmp:document-get-permissions($uri)",
                         (xs:QName("uri"), $uri), $evalopts)

  let $config := admin:get-configuration()
  let $format
    := if (count($doc/node()) = 1 and xdmp:node-kind(($doc/node())[1]) = "text")
       then
         "text"
       else
         if (count($doc/node()) = 1 and xdmp:node-kind(($doc/node())[1]) = "binary")
         then
           "binary"
         else
           "xml"
  return
    <document uri="{$uri}">
      <metadata>
        <format>{$format}</format>
        { for $c in $coll
          return
            <collection>{$c}</collection>
        }
        { for $p in $perm
          let $capability := string($p/sec:capability)
          let $id := xs:unsignedLong($p/sec:role-id)
          let $name := xdmp:eval("
xquery version '1.0-ml';
import module namespace sec='http://marklogic.com/xdmp/security' at 
    '/MarkLogic/security.xqy';
declare variable $id as xs:unsignedLong external;
sec:get-role-names($id)
",
                       (xs:QName("id"), $id),
                        <options xmlns="xdmp:eval">
                          <database>{admin:database-get-security-database($config, $database)}</database>
                        </options>)
          return
            <permission>
              <capability>{$capability}</capability>
              <role>{string($name)}</role>
            </permission>
        }
        <properties xmlns:prop="http://marklogic.com/xdmp/property">
          { xdmp:document-properties($uri)/prop:properties/* }
        </properties>
      </metadata>
      <body>{ if ($format = "binary") then xs:hexBinary($doc) else $doc }</body>
    </document>
};

let $uri := xdmp:get-request-field("uri")
return
  if (xdmp:eval("declare variable $uri as xs:string external; doc-available($uri)",
                (xs:QName("uri"), $uri), $evalopts))
  then
    local:backup($uri)
  else
    (xdmp:set-response-code(404, "Resource not found"))
