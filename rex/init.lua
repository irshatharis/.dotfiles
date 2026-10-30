-- Jump to a session by its label. Labels outlive IDs, so these keep working
-- after a session is closed and recreated under the same name.
rex.action{
  name  = "goto_session",
  title = "Go to Session by Label",
  args  = { label = "string" },
  run   = function(ctx, args)
    local result, err = rex.call("session.list")
    if err ~= nil then error(err, 0) end
    for _, s in ipairs(result.sessions or {}) do
      if s.label == args.label then
        rex.client.queue("session.select", { session_id = s.session_id })
        return
      end
    end
    error("no session labeled " .. args.label, 0)
  end,
}

rex.bind("cmd+j>c", "goto_session", { label = "cohort-app" })
rex.bind("cmd+j>u", "goto_session", { label = "sintj" })
rex.bind("cmd+j>d", "goto_session", { label = "default" })

-- Built-in: step through sessions in sidebar order (not visit history).
rex.bind("cmd+j>[", "session.previous")
rex.bind("cmd+j>]", "session.next")

rex.bind("cmd+j>,", "session.rename")
