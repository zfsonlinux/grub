#!lua

-- Arguments are passed in as environment variables:
matches_file = grub.getenv("matches_file")
class_match = tonumber(grub.getenv("class_match"))

match = 0

function test_device(bus, dev, func, pciid, subpciid, class)
   baseclass = bit.rshift(class, 24)

   if (class_match and class_match ~= baseclass) then return end

   vendor = bit.band(0xffff, pciid)
   device = bit.rshift(pciid, 16)
   subvendor = bit.band(0xffff, subpciid)
   subdevice = bit.rshift(subpciid, 16)
   subclass = bit.band(0xff, bit.rshift(class, 16))

   id = string.format("v%04xd%04xsv%04xsd%04xbc%02xsc%02x",
                      vendor,
                      device,
                      subvendor,
                      subdevice,
                      baseclass,
                      subclass)

   matches = grub.file_open(matches_file)

   while (not grub.file_eof(matches)) do
      line = grub.file_getline(matches)
      if (line ~= "" and string.find(id, string.format("^%s$", line))) then
         match = 1
         return 1
      end
   end
end

if (grub.file_exist(matches_file)) then
   grub.enum_pci(test_device)
end

-- Values are returned as environment variables, too
grub.setenv("match", match)
