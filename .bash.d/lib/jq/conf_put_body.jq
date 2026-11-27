# Request body for PUT /wiki/api/v2/pages/{id}.
# Variables: id, title, body (storage-format XHTML), version (new number),
# message (version comment).
{
  id: $id,
  status: "current",
  title: $title,
  body: {representation: "storage", value: $body},
  version: {number: $version, message: $message}
}
