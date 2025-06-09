require("glua")

print("Writing to data/test.txt")
file.Write("test.txt", "Hello!", "DATA") -- "DATA" is optional here

print("Contents of " .. file.GetPath("DATA") .. "test.txt:")
print(file.Read("test.txt", "DATA"))

print("Contents of /etc/shadow:\n")
print(file.Read("/etc/shadow", "ROOT"))
