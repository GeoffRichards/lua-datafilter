local _ENV = TEST_CASE "test.sha1"

local misc_mapping = {
    [""] = "da39a3ee5e6b4b0d3255bfef95601890afd80709",
    -- Test data from RFC 3174, section 7.3
    ["abc"] = "a9993e364706816aba3e25717850c26c9cd0d89d",
    ["abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"]
        = "84983e441c3bd26ebaae4aa1f95129e5e54670f1",
    [("a"):rep(1000000)] = "34aa973cd4c4daa4f61eeb2bdbad27316534016f",
    [("0123456701234567012345670123456701234567012345670123456701234567"):rep(10)]
        = "dea356a2cddd90c7a7ecedc5ebb563934f460452",
}

-- Data calculated with a bit of Perl code (in the file 't/sha1-gen.pl') where
-- each entry in the array is for a chunk of data of as many bytes as its
-- index, and the bytes all progress in a simple way.
local progressive_sha1_expected = {
    "5d1be7e9dda1ee8896be5b7e34a85ee16452a7b4",
    "654d40aef7d1d67701ffb0ea3d360ec96b1a9d9a",
    "9efb20f73c11e47be0d0ed56607a9a3ee953d224",
    "abc1b679fc953dad0ecb436c4fb9abc6529562b2",
    "ab3bc3943c25939c5d718893e56759eed6547ea3",
    "4aea5d647c96c6db2a53be0f00d7207ff19e980d",
    "33215c2dc757ff5121052a707199c613709d9020",
    "2afbe546d4331073c16580bc602836c9b4297579",
    "64bab3e64fc8dbc59f92f37270f3f059d8bab66a",
    "e4fefe6eac630c1aa8c681bb14687bcae0b5e773",
    "076093a117d310835e06881d0d2b8eb09d89e1cc",
    "207b47f220361085bf719057314029098a679bcb",
    "e1b554be426f494375b1df2ca7653045bade9361",
    "528cf67f267ad97b6f3f05887823fe52004c859e",
    "04a1da4aacd8df254fb6d54b039d525281a0234d",
    "5e64dddc792568b2cd97af8c4f8a4f53d19d1bb7",
    "a22ac2c0943f96f78667964e36e9d63738f69d65",
    "070a032aae52eced85fb1d02028669980d741252",
    "4370781047c0afd2fb1c070846ced5341f9a764d",
    "261c80bfa98bc9ea65572735fa975f958aa5c434",
    "0304a272aec8006949bf9f822ce8402dd2b6c9af",
    "bf79eb2d9b1ac6ec45c5e7115f91055af0bbc67b",
    "333f7f2d4cff0a67adfdda5022d54b094dabba1a",
    "da9d10053a4fd48446338e283b67282eed5dd4a0",
    "65cc462f12791862b07b62419c09d43cb6b91fe7",
    "f94bb93b4bcd3609dce0c692be83f41290576b0f",
    "27fc05a018e42546e89e05737793e44a2c8202af",
    "1dd41f2854d4876d951c7f96bc9724954ee9c057",
    "7b34c18610fb47d8e36bbee6b17eb5f8f2397b77",
    "443086c22737a7f7b15371709f592712ced33422",
    "a74f2ff8de85fbd3ad002555feda90aee633cf6d",
    "047095c1601086e17119892c45b8e96e55b6ba75",
    "72cf24cd2857f520fd5184e7c904c6300311d83f",
    "9b0427f4439cb9bc835d6e123d45dfb78ae5e4e5",
    "edc6eb7289c9c29a7f61db360490991a390b6fc1",
    "e9d08420ebe9cb07584e5e3b904d76c6f12e02a1",
    "617c3b880fe9f9a55d06af8571ea4b34831ba684",
    "44806b1a22ec1144b027061d41d2d84d330c28f4",
    "636e896caa9f205c68511b35eceb8a1e0e095c93",
    "8eda73804191e03e4922c61d697f9b34757a6fdf",
    "7ddff836bf6417c01014b6e90847bf441b8f455d",
    "c43aec0c274ad3bc7b29f16c54dd8559c4dab19d",
    "606ad1adc976684c9c92a6ab1af0991bb0fc4ca4",
    "69295f6b17e87135661ebd4493c56f94a474d183",
    "1cbde81ffed2b4a80d65633930fe33ef1a627175",
    "8def203915e0ae51aac48cfedae5666de885376d",
    "a7f35812caaa5c1192078a761efd5a2086973380",
    "00878b70188a8b93e6a604944478892583d32dea",
    "21ceaa1ebbf27e6dc590fbc679564138ec1df19c",
    "b461e1ce49bab701ec464dd85e7ab91b38379fb3",
    "4be307d6c2e7aa3837f41de264579c74f2e238e9",
    "0e5de862ad212f35607cc4cf47232f0b230b5130",
    "a5462b7801845410e3a551ea518d01062f72eaa4",
    "0e25542b297194a560029307ccd73dbbfa3dcd7f",
    "189aea94dbc8d1823d4a2f5f7a34fbedebc72334",
    "79c78c1949a7a466ed49a3e0fab20620cb17d1ca",
    "3fcdf223a12255d50b88a02726800177fec35e11",
    "ed6529020471ac0354a3f6b84ce11335ad0f3325",
    "1dd1508955d62d4bdf7881ec20a41ffb5491e2fa",
    "fd86e02c6b9ed457addc436eaa3a3237b15ef547",
    "2ed6b739670793412ba6363ceb4fc627ef9d4cf7",
    "b7ee7e72cbc70f0b8758f863a32e0df0bf35a57b",
    "25133d08da61d108171e641b12b82594d1208d54",
    "55370286b097d147abeff481141803fd07027094",
    "0606f0296fb71f47eacd1f62d45e472423a51898",
    "650e1934b4977bfab3008240a2caaa6b08131e98",
    "ed1de3766297e71519d3cc2ce865e38fa28c31ed",
    "cab8c35e8caa3a8ff6c3333096c2b18649dac3c5",
    "69768d1311f2d4de70b232744f8e46599ebca303",
    "f7d8537833081c249f94190ed0ae0e32d619f0cf",
    "c88f7da4a2aa2bcd607a82d69828353b33da2869",
    "98bfa299d2ad54de5bbf0e21bde43de6893a7aa8",
    "937ef7656bd8ee182c92e425ae96f860edfdd1a5",
    "51b289b7cb999b5a180ed22b241d51523fcc8be3",
    "7ef6afac9559229e7148ee3f1c204bd15aa3e48c",
    "bc845a332abed27ddaed1b44f1cb772bae94be27",
    "04fba018e3ed411b361f39de3cec584832fe9cd2",
    "4eacc562d6bc898ac74eab8f14bab897eae716b4",
    "c1d3ac97129f5edd8cc1d6e75f5f7afe4de6a34b",
    "fc57dda94830829b78a33eeea1010d3db7e9e0a9",
    "bfcbc5b2e84f8c3d291b2ee29e3d554aa18ebcec",
    "5bbd65070aa6b79ef190d8ec1c682eed14ee9095",
    "87b93ecb979d89c0d74be623a7808ec182a4b8cb",
    "370dbede4040d062159706439c03cb410063157e",
    "9724c996c369928e041da8bb996296c18b92beb9",
    "c909e2eed23c008907735b24a0b9eddbc3d107e7",
    "3af6d3ecea8d5959abe047f67fcfa0d985d54975",
    "19c9d03cd6bdf592cba69b5ce66a7b490a2f4d57",
    "70ae0bb9d5d597ed6aefa618a8ea4e27508473d5",
    "30e3a1271a2cade90001c8ac7aa6dc89fb9fd416",
    "53179068f82edd06defb3429b40a1c364e6b8f94",
    "7cb553b6f50ddc767cf794f58ed8151e5e588eed",
    "074d0c924724f3175c4fdd218e65435d79996b4a",
    "840954bb3338e59638a98e04a1cc72db04d67e48",
    "da1a1643661469de29e5c5d9a9e58c1cc44db62f",
    "a2678dd4489ed1d5d1bade89ac36f276a22d44c1",
    "52e26be1b953b168bbe903ef2f4ae1dc9892d60a",
    "7c8a0cb22745d59e35572c2669dae3470128eb3f",
    "a4fcdff7a33cfb446d26f9bf6a0e24998b0bbe42",
    "971a322988c351c8cfb16a42f05ab341bcadb4f5",
    "670138786f6b3d4fcdd723161d710005c0da954a",
    "3c18dafbef5845e1889f730528c9d520e27d2427",
    "db7da649969c0253c63b317a23d347dbf6bb7c4a",
    "73ee207ddec848c3f86cfceaba2fcb60e71ed9a2",
    "24c1133ef0e2706da6fcaacf8de7cf7c78ba34c7",
    "f9535eebe0ff944cd2c4bda7cb2ace821715df9a",
    "e54cd40942ea06636186131c4ed606c81f8be658",
    "60882be708883fd0e570b2764d441c4f9c24053d",
    "81b6e7ddaa47d3afa559b0cb582dcaa43b34db8a",
    "548588b1e9be94b0b2600ee8f8d0dea024823627",
    "5b1c378cfe0afadd70e70f9b368a7188230d22f1",
    "c2dbda9d1676e83b6983d4377f4fd7af50b1fbbb",
    "f207cec26a2436b4577ffd8f5ef3702cb7e08931",
    "34ecc514e321dfbf800d35014f15b6c02121e2d0",
    "b1725cbb38b89f3beac27cce427effd933e99395",
    "74da67e287bc4ef285b1b40944c5e931848c5143",
    "334a9b9edd04b3b8b2ee016a1a6bce59b141d580",
    "7e4131c1fa6088faf66eb479d32ed654a9c24779",
    "9fa6f7379cd8c4ebb08ee04568d2a1a671f5065b",
    "26a90250c15286e0fa14370aa0020c90974655ab",
    "85fa43e4cd025fda28605a42e5df8aeba3f2768b",
    "9c236cd255eacfab541fb72858e78d5b3ed138af",
    "f6665a3bcdcdbde856ba71d9f675efdb548a3b8e",
    "18eb7782ec43e37a3cc240504e6f5f194949922c",
    "d7603845e0f18df9916f104b7315de5d120e996f",
    "702fb63f27aad7f7c43199f2cb40effc5e7ff6d3",
    "73e80a2c6ff26f5c9c56687fb7489ca966b044b7",
    "65498c655ccaebefe0f8dcbc379899d4f61eac97",
    "ed84861794334d6f0d3ec0321d76490fb7eb1cfd",
    "1133abe6a525394b766dd9642a0e8dc95789c792",
    "e7bb8ccd39ac6d5b8c9c2d8300533e8cb28588a2",
    "c37918e96d8497060fefa9b62e0c53c217a5c5e7",
    "07a4b8db815e7dc67e4dae21b3e2c4edd1d95188",
    "7d3635e68d1443b56b6134cf40534d5cc7a2c69b",
    "1a5210b578f1863970a2f0ad2f67a1fd40dfbd7e",
    "2a5c73968720cc470b1ec1722929636c89676a1f",
    "c8e711a293f534bb3a146853f1af9f2c1a0cf882",
    "4256cb4846657456ca8bf1f7df4f0f9a119ad4b7",
    "88cff94ca29bb732fccd1b84c2a71e9952455376",
    "32d982a495efa44607541b01db5960da1f8358a8",
    "20cf242c4740f6a644f0162eba1b0457660848a2",
    "b7451a91d408aa8ab91691e2ce82844c98027fc5",
    "71ab0feb73c3ee84e9697ac9b816d0e98163c64f",
    "9ffb7d1c8695cc3bc1a4eb035145a64f0384f282",
    "54837f662ec3ff1a73019501a3bcd6f03bd753b5",
    "22e11b931e0453b3ef5b98ab9621d2263c25d335",
    "670c2593798dffafd07a081c0f3ee05611f0fb4d",
    "6c2d5e8cf5f3b2321d808b2f9221e93a59cbbcf4",
    "996b35c228d913c4cf0a107b10e07b70790f4bcd",
    "9006ba788f18f00bea3533fc50e27caf5ed684a2",
    "5704fd47ce7395ed502bfaadfa9b61077a9c4ce1",
    "f9dff882f474c5f17c54c14f45c3b73f7cec3787",
    "ac653b321e1260279eb9f58274b5dcf1e84f10d0",
    "332f82c5d9fb865b4731cb94f6506da656a6f95d",
    "019b482c9e3a01a57a4f2ea167e51c3da586cb0e",
    "64bbd197ea77c0660cd1e267c2d72b1788d6852f",
    "868c5a433afca682780212f39d5bbb454a84a67f",
    "bfa2b2abf16c86907481900e2c49fbaf17cf6053",
    "5ffda92f374a7f4a08431746cd9973046a4df151",
    "1ecad91f69922b0a0d3e68ea9d348c18331b23ef",
    "2d1b9828ce518a58926beddc62a3aab294e9eced",
    "cadfcf1817f1655b7ca6fcc55ec9291ec4025571",
    "b8757d4b552438d81afdd29ebec3bb13a4b906b6",
    "847dba431117d438cd823a22f5f08c366efc41ba",
    "37a5fc63e32df4f190930e25fc1c83aad855bfc7",
    "13df8275a7a5e0b4ca0b7b484b5f77a21794fe25",
    "3744254ff8d99c6d26a6f4e8c60ffad097807a4e",
    "4721ce280a71aa473b0d423d82f88f5f1e9d3d4f",
    "c4ed7e7526d0fffecd950efea2f5a1b95c645f4b",
    "ce65087a508c913303c2d3b4aed77fb368f3d0b4",
    "69dbf298b829b38fa53e17a5e4c4207938cb3afe",
    "29b9eba485786500c6d8c62a10785e1bdeb338ab",
    "99c297334769f3ad3dcfe70c11272926fdb77f35",
    "b1303865988704f647d99291868f4eeb856f35c6",
    "2b49c6dc2f2c102a63bb43b4e3a6d6916c14c41b",
    "688a1bb1e6c6fa2fa73977dfd54b3732c6f60c1e",
    "7577ef85f4b228a2c59592b324a6963449c6e4f5",
    "f29302258f2560333cabdc07547f1d713dd4e829",
    "de72bfacde1388faad206ad77b87de5bbf881e8a",
    "c05546dfc2f6d758d906cdd4fc0e65880abb8e22",
    "423cf753b1c82eb7445c60dd16a886e493891c33",
    "0820256d309e1c66fc8c57c0e117c4c70b83d33a",
    "6867018f2bb1d5d464d68252364d0b2dc0a48123",
    "4f789968012c757848a58e1511eb2494bc39b8c9",
    "226598caf11da1a4372346ca98fb9d513b32220d",
    "9582dcba8fe25b2dcdc4257b1b1e3de7abe6fc31",
    "c89a16c32f9ba9bb3417388f0376d5b686af0a59",
    "1e5218c493776e52017d6e0dc279441b47476013",
    "ab4e0daea6b9f89aeeaa7512249580f1572ca6c9",
    "5486d3830ea5fc89a3f27cb30efd5c36b0115cab",
    "f4a937329c643b814c23c88a57628a75156154cb",
    "b52c67567762480487f50d97abd14d92e75596bd",
    "5314edf160e668c80bae0eae3416a74722f7a987",
    "d225c373c395658583a3aa98f58491ffef1a65dd",
    "d119be08d6aacf4b06acd58805f2c24c14a68e88",
    "854dbf5d086d43a0bda400398190f3e54fd4c896",
    "c169ecab76b9cf02a44ed7c54bc42c2c0d1c997e",
    "a0f5bc64833ddf521fd4501105a1e682d3402856",
    "60c5e78ec331fb938e7ee5719da8880c8ef84535",
    "3e1881e0e366c9ea130d7c55a366ba00cba6f433",
    "66d1aa2aebbfb3eaf7ace4cfe45451009a8caac8",
    "9ae48b822c00bafe62bbf78e8f54c2a07eabef0d",
    "9402c8afd0173c4ef70f164a6e736eb2a4ec4e2d",
    "0ffe211ce08a4370f230a6aca461812dd24bca32",
    "49c9b830430fa8cf3e73e6a0ead34bd37fbb6635",
    "e11b73e661d12a9d51c86edfc0d570d131847609",
    "3333b3e6cf4c89be60b58e630c67bfb11debf496",
    "138a43012f6394fedd767d42273d7d821ff2f80e",
    "7fdd265157c81f5506de788082764b6a602b1e08",
    "dc652b39217c5c3e0c0db8e4775762f453e4c467",
    "06a67f6ba2dc6badcb90a26d5c4acb494cbb0d16",
    "aa9a32fa4b782ce92493cab6d9ef5c3b85bc4798",
    "3a77b46fffa39a85fa23ede03693b7f7893428a1",
    "4df87e883cf241dcff3e81ed3527e3f455da6d7f",
    "6efea2b0a37dac38f4d27807c1098821a70e1f47",
    "a7424a40a39000349dde6cc7b64e9acb5af57b08",
    "1f31fad3a62fa9ab35bddb97923cee5dbfeaee87",
    "abfe7cf43f27ceb25ebfd5767af39435ed7bc8a5",
    "532ced5fbcc7156d0c87bb986e5df49e67b29237",
    "0a82c443b24e1e4908fe7c413f4d46fc57d56e4e",
    "86e634996a6de1cc75d0b762a79d3c061146e54e",
    "4a1887d644dfbd9f849e094454cb65eb9791f3ad",
    "c9fa0ce4a253d3ea9fcaf3a7555096084b9d9df5",
    "734cd8d3f67cd4d0414feb4734eeba9b6afe88e4",
    "fc1d4378527c783aa58d078e760cb2e91a40f701",
    "80bb6f01ddfe8cfc8225dba7da79755c45b6e696",
    "16c78b5475ede8b9bc8d6848efe5d9769ef0628e",
    "8f27ffc6e8e8cc6650dbba56e697b118a6e3ff8d",
    "ea123dccf145aa275381fed3639946a2ea795670",
    "38ee38416691a5a90058bdf98dcd8d22263c8ca2",
    "80b7a656424cb6ec18de80da2dac254b83fda479",
    "a5f15b73b81555e4a363d7eadc85ec7bca12c9b8",
    "247b6e68af6be55aa166a3810580f1eef9a090e0",
    "a7ece5b3e8fe457aa0586d594088c30a1f7b4e11",
    "483f10a6d17c7bc5eaf11815b17b3917722cfccb",
    "2b0d413805d9a086c631deb8f49be1793f54ca71",
    "62a67d23f4d66406a6fc99a9dcf39d16319f84f1",
    "3102b537806471e3869cd4cab39846c755640ff9",
    "560a2257aaf27e8508847385b0dbc1c65ea2a002",
    "a3b1fedeaf00bb7c8dd1fa51221c20ddb683fee1",
    "68101a5e621fa496482297e5187f5a82129d8647",
    "4fd3c702c6c86a2415932643aa408399488d6307",
    "f114ad2cb90b8a7534b736c84460f71fda7ee5de",
    "be3e59c96f76442607bfff3ea46887801dd5fa2b",
    "4c41c69e5fd7449849a3b29793bc05eb0a07f085",
    "ad429fdc98b90d326e44e52680d576ec323f6591",
    "79e6c0d0d4ad13ca2717c31c9ab1f5adc90ce590",
    "4d839d7c2d67aae40ab464901edd155b424d6cba",
    "b85dec366570996e4d28875a17911d1fa9ed0b94",
    "1dc0de25687287502b6c7477c5f535fcf9097d7b",
    "82a099321d78a958ae60649304e2cf34e33379d1",
    "0b27f10768e6b685dc98fe0c8d1a947a00bca627",
    "29c1aa771e30c8ff835ce663f60d76ee751bdd78",
    "48acc4a0da8d622707de102f6fe93e0b2c0eb160",
    "9dc93068d2806dcec97f2301a8504ad4c9dac7b8",
    "cc6b8e641f76edcee1034ff46d970327918f2dfa",
}

function test_trivial_obj ()
    local obj = Filter:new("sha1")
    is("da39a3ee5e6b4b0d3255bfef95601890afd80709", bytes_to_hex(obj:result()))
    local obj = Filter:new("sha1")
    obj:add("")
    is("da39a3ee5e6b4b0d3255bfef95601890afd80709", bytes_to_hex(obj:result()))
end

function test_misc_sha1 ()
    for input, expected in pairs(misc_mapping) do
        local got = Filter.sha1(input)
        is(20, got:len())
        local input_msg = input:len() < 80 and input
                                            or input:sub(1, 80) .. "..."
        is(expected, bytes_to_hex(got),
           "SHA1 of " .. string.format("%q", input))
    end
end

function test_gradual_size_increase ()
    local input = ""
    local byte = 7

    for i = 1, #progressive_sha1_expected do
        local expected = progressive_sha1_expected[i]

        input = input .. string.char(byte)
        byte = (byte + 23) % 256
        assert(input:len() == i)

        local got = Filter.sha1(input)
        is(20, got:len())
        is(expected, bytes_to_hex(got),
           "SHA1 of " .. string.format("%q", input))
    end
end