<?php
        $old_account=trim($HTTP_POST_VARS['s_mailid']);
        $old_domain=trim($HTTP_POST_VARS['s_domain']);
        $new_mail=trim($HTTP_POST_VARS['s_mail']);
        
        exec("./add_forward.pl $old_account $old_domain $new_mail");
?>
Finish!
