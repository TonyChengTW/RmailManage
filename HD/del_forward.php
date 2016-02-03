<?php
        $old_account=trim($HTTP_POST_VARS['s_mailid']);
        $old_domain=trim($HTTP_POST_VARS['s_domain']);
        
        exec("./del_forward.pl $old_account $old_domain");
?>
Finish!
