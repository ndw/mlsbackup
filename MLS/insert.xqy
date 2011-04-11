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

declare variable $doc
  := try {
       xdmp:get-request-body("xml")
     } catch ($e) {
       (xdmp:log($e),
        xdmp:log(xdmp:get-request-body("text")),
        error(xs:QName("ERRBADREQ"), xdmp:get-request-body("text"), $e))
     };

declare function local:insert(
  $doc as document-node(),
  $uri as xs:string)
as empty-sequence()
{
  xdmp:eval("declare variable $uri as xs:string external;
             declare variable $content as node() external;
             xdmp:document-insert($uri, $content)",
             (xs:QName("uri"), $uri,
              xs:QName("content"), $doc),
             $evalopts)
};

let $uri := xdmp:get-request-field("uri")
return
  if ($doc)
  then
    local:insert($doc, $uri)
  else
    (xdmp:set-response-code(406, "Resource not acceptable"))
