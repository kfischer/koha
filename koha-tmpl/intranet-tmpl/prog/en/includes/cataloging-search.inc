
<div class="gradient">
<h1 id="logo"><a href="/cgi-bin/koha/mainpage.pl">[% LibraryName %]</a></h1><!-- Begin Cataloging Resident Search Box -->
    <div id="header_search">
        <div id="addbooks_search" class="residentsearch">
        <p class="tip">Search the catalog and the reservoir:</p>
            <form name="search" action="addbooks.pl">
                <input class="head-searchbox" type="text" name="q" size="40" />
                <input type="submit" class="submit" value="Submit" />
            </form>
        </div>

        [% INCLUDE 'patron-search-box.inc' %]

        [% IF ( CAN_user_circulate_circulate_remaining_permissions ) %]
        <div id="checkin_search" class="residentsearch">
            <p class="tip">Scan a barcode to check in:</p>
            <form method="post" action="/cgi-bin/koha/circ/returns.pl" autocomplete="off">
                <input class="head-searchbox" name="barcode" id="ret_barcode" size="40" />
                <input value="Submit" class="submit" type="submit" />
            </form>
        </div>
        <div id="renew_search" class="residentsearch">
        <p class="tip">Scan a barcode to renew:</p>
            <form method="post" action="/cgi-bin/koha/circ/renew.pl" autocomplete="off">
                <input class="head-searchbox" name="barcode" id="ren_barcode" size="40" />
                <input value="Submit" class="submit" type="submit" />
            </form>
        </div>
        [% END %]


        <div id="catalog_search" class="residentsearch">
            <p class="tip">Enter search keywords:</p>
            <form action="/cgi-bin/koha/catalogue/search.pl"  method="get" id="cat-search-block">
                <input type="text" name="q" id="search-form" size="40" value="" title="Enter the terms you wish to search for." class="head-searchbox form-text" />
                <input type="submit" class="submit" value="Submit" />
            </form>
        </div>

        <ul>
            <li><a onclick="keep_text(0)" href="#addbooks_search">Cataloging search</a></li>
            [% IF ( CAN_user_circulate_circulate_remaining_permissions ) %]<li><a onclick="keep_text(1)" href="#circ_search">Check out</a></li>[% END %]
            [% IF ( CAN_user_circulate_circulate_remaining_permissions ) %]<li><a onclick="keep_text(2)" href="#checkin_search">Check in</a></li>[% END %]
            [% IF ( CAN_user_circulate_circulate_remaining_permissions ) %]<li><a onclick="keep_text(3)" href="#renew_search">Renew</a></li>[% END %]
            <li><a onclick="keep_text(4)" href="#catalog_search">Search the catalog</a></li>
        </ul>
    </div><!-- /header_search -->
</div><!-- /gradient -->
<!-- End Cataloging Resident Search Box -->
