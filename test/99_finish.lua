lunit.main(arg)
if lunit.stats.failed > 0 or lunit.stats.errors > 0 then
    os.exit(false, true)
end
