const bcrypt = require('bcryptjs');

bcrypt.hash('123456iii', 10, function(err, hash) {
    console.log(hash);
});