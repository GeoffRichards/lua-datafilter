require "datafilter-test"
local Filter = require "data.filter"
local testcase = TestCase("Algorithm md5")

local misc_mapping, progressive_md5_expected

local function int (x) return x - x % 1 end

local HEX = { "0","1","2","3","4","5","6","7","8","9",
              "a","b","c","d","e","f" }
local function bytes_to_hex (s)
    local hex = ""
    for i = 1, 16 do
        local byte = string.byte(s, i)
        hex = hex .. HEX[int(byte / 16) + 1] .. HEX[int(byte % 16) + 1]
    end
    return hex
end

function testcase:test_misc_md5 ()
    for input, expected in pairs(misc_mapping) do
        local got = Filter.md5(input)
        is(16, got:len())
        is(expected, bytes_to_hex(got),
           "MD5 of " .. string.format("%q", input))
    end
end

function testcase:test_gradual_size_increase ()
    local input = ""
    local byte = 7

    for i = 1, #progressive_md5_expected do
        local expected = progressive_md5_expected[i]

        input = input .. string.char(byte)
        byte = (byte + 23) % 256
        assert(input:len() == i)

        local got = Filter.md5(input)
        is(16, got:len())
        is(expected, bytes_to_hex(got),
           "MD5 of " .. string.format("%q", input))
    end
end

function testcase:test_from_file ()
    local obj = Filter:new("md5")
    obj:addfile("t/data/random1.dat")
    is("a3f8e5cf50de466c81117093acace63a", bytes_to_hex(obj:output()),
       "addfile() on random1.dat")

    obj = Filter:new("md5")
    obj:addfile("t/data/random1.dat")
    obj:addfile("t/data/random1.dat")
    is("b9054bf8fd1941b722ec172efdb7015e", bytes_to_hex(obj:output()),
       "addfile() on random1.dat * 2")

    obj = Filter:new("md5")
    obj:addfile("t/data/random1.dat")
    obj:addfile("t/data/random1.dat")
    obj:addfile("t/data/random1.dat")
    is("b4950de76365266129ccad54c814fddc", bytes_to_hex(obj:output()),
       "addfile() on random1.dat * 3")

    obj = Filter:new("md5")
    obj:add("string before the file")
    obj:addfile("t/data/random1.dat")
    obj:add("another string between two copies of the random chunk of data")
    obj:addfile("t/data/random1.dat")
    obj:add("some stuff at the end, and this nul should be included: \0")
    is("ef988d269b28ab947437648d63d68a56", bytes_to_hex(obj:output()),
       "addfile() on random1.dat * 2 with strings mixed in")
end

misc_mapping = {
    -- Test data from RFC 1321, appendix 5
    [""] = "d41d8cd98f00b204e9800998ecf8427e",
    ["a"] = "0cc175b9c0f1b6a831c399e269772661",
    ["abc"] = "900150983cd24fb0d6963f7d28e17f72",
    ["message digest"] = "f96b697d7cb7938d525a2f31aaf161d0",
    ["abcdefghijklmnopqrstuvwxyz"] = "c3fcd3d76192e4007dfb496cca67e13b",
    ["ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"]
        = "d174ab98d277d9f5a5611c2c9f419d9f",
    ["123456789012345678901234567890123456789012345678901234567890123456" ..
     "78901234567890"] = "57edf4a22be3c955ac49da2e2107b67a",
}

-- Data calculated with a bit of Perl code (in the file 't/md5-gen.pl') where
-- each entry in the array is for a chunk of data of as many bytes as its
-- index, and the bytes all progress in a simple way.
progressive_md5_expected = {
    "89e74e640b8c46257a29de0616794d5d",
    "7240e7b150d6025912db8cdcb3feebeb",
    "88301910845f8f4b88aeedce3cb1c4c9",
    "31c359a107aa85d5482e59ed5a24a1c2",
    "8fc12582721c9049c94b319633573f0f",
    "5b8051a13d6d44e031cab9cd2e9eb228",
    "2779219adac2242744ca765699b84df9",
    "c3959ba26023891d050d42792e5e173a",
    "15f44f8d145d043172477e36f3a1f346",
    "8a3e55ec95e1a3ef23c79c52d1bf72cc",
    "d7d031d1387e5313c1a7eb02fc836166",
    "98897f26186be77797e29994804e5b93",
    "268651a5a2ae63a78db619877025d4fd",
    "8d391ebc78bc811e4c5c022aabc625b5",
    "e5a5ce523ec61bedc0d212b053116fd3",
    "2e9ccae274ee36377d9227cf6b71976b",
    "8a3b44b957e8f1af8a4129172fa91382",
    "a8c38b5fce9ce49f4f261926aa00426a",
    "4b97d7d215627ece5ddc18f6b3813235",
    "fcd6a7fdbb76fd83e5f4d43ce6380666",
    "6b7ec7c363e76265b6a8c930747bafa2",
    "395662ec023352ddab366bbdcf9d0042",
    "cc8adca2bf689eb3707952766c426f21",
    "4db9d99d0f0d71de20d8aff2b04f4ac4",
    "3dafdeec56a9db606917a825d66ada8f",
    "efb2d65eb1a3706dbd6bba6f40b05dce",
    "71ee81fc27e7f5f5882c74b619f7150f",
    "cf493506aaca99256856170f7b0257ad",
    "b4b9e99701ef0fc313cde858c891b311",
    "af76524affbc14020a180998faa89de2",
    "218703b715d947b23ff185b402063d97",
    "dcc961633d2738de9e898227e276e789",
    "7c8a68edf6fb40763d6c0ff951b21960",
    "e0afa0d7984bcfaf953edc472eaf6605",
    "aa0e5cdfe2ff22214fff041f6233cdbe",
    "bd9485ea5a5610b7d314579f106a5161",
    "c7e79c6ff30732a0ac3bd257d5ced98d",
    "08a98a8a7ea8ea6c7b310249c03b7121",
    "a44f7ae0f2ef8d815451440eb6f594f6",
    "17b7f75403eee0c0eff3f2f0928a7f60",
    "1da61992f1123a0872d00a50452aa174",
    "9406acf29fbcc711501b3e228699c5ab",
    "703eaf26a15d172992e186ddf76a842c",
    "b2576c8ce4ca12a292c7b5fdd92ffba4",
    "6bcc790decd1e629c3141c63d9f98554",
    "8febf3e7555aa2fb79b691b83a05d57b",
    "95048660de69717792bbdb4da92412db",
    "f9b9f00f82d5a2a2fa3b860da82a416a",
    "b6b522e3bfc6ce9f0873c212506f0b21",
    "c2d131765ab338d4e3faa8f768325a86",
    "7a9760954647ad443dbfe8e8a106b821",
    "030ea05631f3b82bf1872849a80ac5ae",
    "add8b85f476f52b35401c5d34f145bb9",
    "13b53ac4c6e58605694e26e79c072935",
    "d27d8878b56868d8a9090170d2acfbce",
    "cda66572dc870cf8c6cacd07811ad272",
    "6ae022259bc385938b3e65a2954832c9",
    "9c13a3a772f1260c13d1326bfff573fa",
    "99ecfa70f7bfe0a2daf7b77838233b12",
    "5f3ca466ea1f09590f8dbf87aaf08e5d",
    "13f7c93d0d3f6854dfffc62b621b3c99",
    "e92d35916e0de3a03c6b577885eda22d",
    "fa1ad25ec5960f37cfbe249d441b3241",
    "f5fef1c74c86e2b6fd68199458bacd59",
    "f4bdcb5b126b8b6497a718301334c18b",
    "0b10e316a099c5211eac659652ce2f2d",
    "7e521d71c4774bd587b461daa8076958",
    "b9048f36095d24a8ced038b78023fa52",
    "7bf3e3ffb5cb08af884c3a59758acff1",
    "4600da41d1d93c746a81c6dfc9eaf219",
    "534a6b468a183200b0e547299c99debb",
    "d9e1b9269425e714fb1fa088510e871c",
    "0afac272e4150ab42f7bc9f116ccc3a7",
    "9db432077aedcb612869e1797adc5764",
    "016b45803f2532d6051d8636629a9f0e",
    "222b1092bbae19a524c98b27a1cac1b6",
    "8811ce6a671596f2bf80aa89239d2525",
    "c364f70cec48d333c179ee3fe754ec2e",
    "d3172a6e1a662684b1cbb2978d60340f",
    "3120d9594b6c3755d6feb071f51e46fc",
    "b4a2a933067d40a89a5186967e3480f2",
    "2af7fe12ff43a083e800046220fa6c9e",
    "9779268862bb6738755a0ba31b2dd84c",
    "a756bb43d83e3f74edf4ad5945c2485d",
    "33164f9bd9f826e8c9446d32bad22acf",
    "abb34d9a08c3d7ab2a7e0db8c8559758",
    "d3dd6c4507f9ed19677564df2733d4a3",
    "757f8d9400fb9bfb51fe9a4bc62e1c22",
    "3bc0daf3468eb31e43b352e10dc824d6",
    "9ed80da75621199fde01f74707d91f26",
    "73dbef39378325090f3d006c9c240d09",
    "17cc6ac81aa6d5080cfafe69c652390b",
    "2565dd7386ca098be34c49dbaa01457d",
    "18c560001385f674d76cb8da239fcf89",
    "35ec4289ea9c1a7daa6f31f38bb7741b",
    "34d3ce9550688f418d885dd1ea5c83c0",
    "0664070fa900c0f3ac0b8d449d0337a8",
    "81b2c5767ee92db010c8fded0cc85b74",
    "39527094c6ba2f482186428a22ba8f7f",
    "0c2256bc176b7aa72c64703cc62f4756",
    "dc863c6ca6ad878bcd54ee1ff127f8c2",
    "d69c27e91fca527ca2659a6ccf697673",
    "fb90adbfaf09acb14076cb69d80d0e9b",
    "94d3e69b241db8e06b9383e54eda394b",
    "aa944a5000e19b11d00392f6d8bfa886",
    "ad35d72d040a5f619edc921532009c87",
    "0fbc6e5fa24826dcaca7e7e30f3f67a2",
    "a1b4ad040e07ad59b6a97da742aabf26",
    "6a21e824400f8a528be092cb3448c2ae",
    "625e8e0f736815e290290a8639f68327",
    "5978c9abbc134c33ecabf361296699a5",
    "f52df035041d7b35eac734708dd92519",
    "22ffbe6b5d7119a2c72b23fbf6f11644",
    "14239de98026c29da03065f4780e6235",
    "daf655d8b63698885faba199fd2eef15",
    "3561bd60a6dadcc6811fa4fe448a597f",
    "150cab16147561855d4eaf2208a45101",
    "4d72ee11cd0b6c1dd9863eeeaceeaf6d",
    "df32d4bf0ffe6780cf09413ac70bea48",
    "55c86558b71f037d3af8476bbd011e94",
    "8b39ab3533a75cc6e045d4cb4e803892",
    "36eceeeb06c4fa211363cd246c908628",
    "520f7de7fe76c02db9723d07eb8e2f6d",
    "5c448a4977f677d7af528086c83f7a06",
    "14a4b79836438b7b8913dd6499699c5f",
    "f5ff9129e9d58ec31b01694edd3f3421",
    "677f855124ab0f09484592d06bd2d96b",
    "4effcd63d3c8db61da2a9a23e01c48db",
    "6bd9aba84ebbc47306381540dc515521",
    "d886759dc59f4a8c2239fb8828031843",
    "a96c73c431c801a66524a3aad930cc58",
    "4e6af120c39700c6f2e141339ddaee4a",
    "b4212f4b923c979c249d88e95cc6baa1",
    "a123e4d9fcf32cd2a1b1c33c4eb54146",
    "755562bca2168a1462c19d5eed0cc493",
    "2984b42c59e9fdbcdddebda914e7f731",
    "5a7452ba8cc152ef551b76c5746dee60",
    "069ebbb114964569ea16931ed39eac07",
    "66995604ff177a0350408b3c720d76f9",
    "8e9fb5f02794c0686fdab8bf0048277f",
    "f98b787db9f5035ef4bbad4c1de84c5e",
    "05e76be9a341446b8da455c324eaca40",
    "0663cf543e1095b6831746b72ee62183",
    "5b24404e7db0788d41145eedac42f12e",
    "c9fadb88620420eaad1964e30302ecf1",
    "2160db611647b47b12fbce9b1c15936b",
    "1a7256cc76c0ca7c350c7fbe39690a44",
    "7777560d615e364d69219ce9a3c698c1",
    "c1f1f7bef53d2b1b3800ca0dba9fd410",
    "5c50f06f4dbbed981ec6b647cdd1b450",
    "906d23fb646141fe73c1838ba169abe4",
    "878d660f18b1e74b386593267e249a1c",
    "cee962c3ccb39973d2264dcbd30926b5",
    "5b7b3bbea3fce59ae7a750127b813e04",
    "e23336f40f486279d474a6d77a49341c",
    "4a4cce96811aa9afd1e180090030533b",
    "84553e93d5be54f1ea047f6bb961f8d4",
    "3476288a8bcb378ea6de2372fd7fac30",
    "d45996ba7fd7cc6200a6a40c76d778f3",
    "02dd6a93c83f5534fb2b4062f51cae3a",
    "7910d3a17229cea2bac5e78443b97ade",
    "ed7a2f386e0a4ba07ac6e1ee8c639dbb",
    "667e4f19157901842877c35fce89083c",
    "9a698be051055e6ff73689ccac1a258e",
    "d7ba14d005e849431ac930914758afe4",
    "1cffc4022ca9d302b67556d36b3c2aaa",
    "7d77de2776230c65dd3b39a593cf420a",
    "64cdfa240fd3cf893b4af90d35d12905",
    "b61d531d8f3ef1f6e397ee6a23f2a17f",
    "9c0117dfa32108c73d1558d82acca89d",
    "9aa18cb12af86cd5e537e7893cbbf1c9",
    "0627f83406567a3aef21e31a0fd7d55e",
    "f448d064a92a14bee050b4be96262ad4",
    "a8743a010ad33108d2499476c5c77113",
    "568d41f07d759b59bdb93c93c107dd7d",
    "e01c1f055443470c064ebcf40341bfd7",
    "36df30f18205160d2df9286685ce8265",
    "9da39df6efd0767b4cb2033a88c056e2",
    "1a2e56248e5ee0a409259b7a278f1e8b",
    "1dc38a078f43e10dbd2659aaa3420654",
    "2362350e33dbf86e402023f61b7cc899",
    "b29fe1bded2355333f0dcde7d8b569b4",
    "d970b54334c07178332196b231ef0d7d",
    "6d98d6cd5b8f7a33ee0e1255874c7e58",
    "c6433c876c87f03e3699df398899ea3f",
    "9000ef0c3aded62a32f19715a87b38de",
    "b00203122224fe9f8401dbd482b2de7d",
    "da520090e9d8ddb3b72f7d26fd7f1a9b",
    "3c11d3f66822589d4aeda93fdd7fb90e",
    "5c0d64db5893df7309d4df7385fcc984",
    "447a9c90ede2b94599d43498a20b5193",
    "dc7d36f8b2405f367b6321e7f02aef7b",
    "f511a8e1d0760453ba7ce95363d024b2",
    "c34ed9722a23c675a0ba6270e9deb1bb",
    "89897279a6a5da68c73028090b3b9d7b",
    "5f210a8ffda2781c865753e3b65257e3",
    "18cdff7238819f207c4f31348d4c3e3a",
    "60782df42f86f69a498db229fd6616d8",
    "37de7e5e4b19356ec4021535801edb10",
    "4eb176fcd66b0d779361fadaed089edd",
    "9cb03eceeb411da026432444b82d2ea6",
    "b2438fd57c7e6e735e109199a84eecb8",
    "1890e73ac2bffc95faa081e0303e93b2",
    "dc18e4de730ae242a0fcb3f29ce0394b",
    "262e2d3ee458a81e8b8a42db96160d26",
    "4310f1f8cac06414aeb0a1372506ba7b",
    "d399e358932e7b543009bb7cea5bf124",
    "bfaa951cd2bb24516af8a04ecd00acda",
    "3828cf16d88a51b6652d9261b0b0619b",
    "ae72263136bae239b9b431b1edfd2891",
    "b8a84ab89e7ebdd4f82498fd8411c146",
    "2e15e52184777f43f6a53798b6afebf0",
    "ba5345e9d7a2672f04b0cc16dab13a6b",
    "92f9d9831c98b12225700d5301a82e98",
    "a18268dd4ae2ea21d42598f34a1b919f",
    "277331ef82901d40b865db4970690787",
    "848436e76a90a95cf2b54dfde48d032c",
    "fa3008030775fd3452d315554b3efe05",
    "4b635263a641766a29fd25e8c985e295",
    "dfc4179829f06949093ad747185bc8e6",
    "f4c390915048a237ae5ec8e91bbe4257",
    "46ec9286edf72da52660ddcfe86e6056",
    "8b15a64cbcf3674a5544e7cc21f77006",
    "f9a7199bbb14868f4c25d31a965506cc",
    "547dd9303985b32a34a8cc1fe9c48324",
    "aa4c9767459152227ab8c0b9665776c6",
    "fd031730fe839fa1622a7a2be544c3eb",
    "9a414f7377e9d80008041575c7381a77",
    "25aa5ef1e6f92bdfe3831b621199544d",
    "88b205f5e94305b3414ff8aa5645b5ec",
    "860c4611596ec9f9008023a3bb1f814e",
    "4eb1e7d69368b90eac18fc335ca60e4c",
    "78efc24bbd5426a1106a9124b60a2bcc",
    "9586174868369fd3ceb217988d1c33cc",
    "644b978ce33d2fb14c62767b24c1d99a",
    "4e4ee1f8a3d967e0e859eee885b9e25c",
    "717ad34511fd792ee167c21616c30546",
    "cd47470766f7420b9dd5611e8411f248",
    "e12c2eea66fb3a61e7564009d5a9b859",
    "e445823deb473c71026b98954ad327a3",
    "ba76b70939068630a284d873e2aae20a",
    "0aee9c1d179a7a03e7c35cf5ab9cd7d2",
    "faed0a07af39c467e435195336860bf4",
    "8f5d742e4ca10b1d325ee62312db06f5",
    "cf6c490d38c2b9621886931610bfc95a",
    "cdc4b0657afeaca5ff2c7f7284ca1bf9",
    "e6f5db502a1fb7caab0ba697eef4d6f1",
    "cc8f8e8f3d25540ed862dcb22d7bffc0",
    "5249a8cc3add3daf17d5f045056a28ef",
    "b5c4c6fd09829184c171639f51d70c6e",
    "2ba1290ac9151e403e26c2d43a18fa35",
    "57859e4ce1ad4ad7d52241738f93c2c7",
    "5f7727f587baca10b1d7073568bef265",
    "fda4ee8777d7551bbca7f2224f3681fc",
    "9abd143326bf7260b56acf19b8cef39e",
    "f9b574526cc9a4528d45f8816706fa83",
}

lunit.run()
-- vi:ts=4 sw=4 expandtab
