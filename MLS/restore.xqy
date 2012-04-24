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

declare function local:restore-document($doc as element(document)) {
  let $uri := string($doc/@uri)
  let $format := string($doc/metadata/format)
  let $content
    := if ($format = "text")
       then text { string($doc/body) }
       else if ($format = "binary")
            then binary { string($doc/body) }
            else document { $doc/body/node() }
  let $perms
    := <perms>
         { for $perm in $doc/metadata/permission
           return
             xdmp:permission($perm/role, $perm/capability)
         }
       </perms>
  let $collections := <collections>{$doc/metadata/collection}</collections>
  let $props := <props>{$doc/metadata/properties/*}</props>
  return
    xdmp:eval("declare variable $uri as xs:string external;
               declare variable $collections as element(collections) external;
               declare variable $perms as element(perms) external;
               declare variable $content as node() external;
               declare variable $properties as element(props) external;
               (xdmp:document-insert($uri, $content, $perms/*, $collections/*/string()),
                xdmp:document-set-properties($uri, $properties/*))",
               (xs:QName("uri"), $uri, xs:QName("collections"), $collections,
                xs:QName("perms"), $perms, xs:QName("content"), $content,
                xs:QName("properties"), $props),
               $evalopts)
};

declare function local:restore-external-binary($doc as element(document)) {
  let $uri := string($doc/@uri)
  let $format := string($doc/metadata/format)
  let $_ := if ($format != "external-binary") then error((), "Not external binary") else ()
  let $path := string($doc/body/@path)
  let $offset := xs:double($doc/body/@offset)
  let $length := xs:double($doc/body/@length)
  let $perms
    := <perms>
         { for $perm in $doc/metadata/permission
           return
             xdmp:permission($perm/role, $perm/capability)
         }
       </perms>
  let $collections := <collections>{$doc/metadata/collection}</collections>
  let $props := <props>{$doc/metadata/properties/*}</props>
  return
    xdmp:eval("declare variable $uri as xs:string external;
               declare variable $path as xs:string external;
               declare variable $offset as xs:double external;
               declare variable $length as xs:double external;
               declare variable $collections as element(collections) external;
               declare variable $perms as element(perms) external;
               declare variable $properties as element(props) external;
               (xdmp:document-insert($uri, xdmp:external-binary($path, $offset, $length),
                                     $perms/*, $collections/*/string()),
                xdmp:document-set-properties($uri, $properties/*))",
               (xs:QName("uri"), $uri, xs:QName("collections"), $collections,
                xs:QName("perms"), $perms, xs:QName("path"), $path,
                xs:QName("offset"), $offset, xs:QName("length"), $length,
                xs:QName("properties"), $props),
               $evalopts)
};

declare function local:restore($doc as element(document)) {
  let $format := string($doc/metadata/format)
  return
    if ($format = "external-binary")
    then
      local:restore-external-binary($doc)
    else
      local:restore-document($doc)
};

let $uri := xdmp:get-request-field("uri")
return
  if ($doc/document and $doc/document/@uri and $doc/document/metadata and $doc/document/body)
  then
    local:restore($doc/document)
  else
    (xdmp:set-response-code(406, "Resource not acceptable"))
