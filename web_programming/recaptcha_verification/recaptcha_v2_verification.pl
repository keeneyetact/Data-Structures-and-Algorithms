#!/usr/bin/env perl

# reCAPTCHA is a CAPTCHA system, that is a system that allows web hosts to distinguish between human
# and automated access to websites. More info - https://www.google.com/recaptcha/about/
# You can register your site in google reCAPTCHA at https://www.google.com/recaptcha/admin/create
# You will get 'Site Key' and 'Secret Key'.
# 'Site Key' will be put on front-end side while 'Secret key' will be on server side in environemnt variable.

# https://metacpan.org/pod/Mojolicious
# https://docs.mojolicious.org/Mojolicious/Lite

# This is a simple Login page. We will be authenticating user.
# After success they will get a home page where we will be welcoming them and they can logout from there.
# In case of authentication failure error will be thrown.

use strict;
use warnings;
use Mojolicious::Lite;
use Mojo::UserAgent;

# Add your 'Secret Key' here
$ENV{'CAPTCHA_V2_SECRET_KEY'} = "";

sub is_valid_captcha {
    my ($c) = @_;
    my $ua = Mojo::UserAgent->new;
    $ua->insecure(1);
    my $param = $c->param('g-recaptcha-response');

    my $captcha_url = 'https://www.google.com/recaptcha/api/siteverify';
    my $response
        = $ua->post(
        $captcha_url => form => {response => $param, secret => $ENV{'CAPTCHA_V2_SECRET_KEY'}})
        ->result;
    if ($response->is_success()) {
        my $out = $response->json;
        if ($out->{success}) {
            return 1;
        }
        else {
            return 0;
        }
    }

    # Connection to reCAPTCHA failed
    return 0;
}

# https://docs.mojolicious.org/Mojolicious/Lite#Helpers
# Check for authentication
helper auth => sub {
    my $c = shift;

    if (($c->param('username') eq 'admin') && ($c->param('password') eq 'admin')) {
        return 1;
    }
    return 0;
};

helper verify_captcha => sub {
    my $c = shift;
    if (is_valid_captcha($c)) {
        return 1;
    }
    return 0;
};

# Different Routes
get '/' => sub { shift->render } => 'index';

post '/login' => sub {
    my $c = shift;
    if ($c->auth) {
        if ($c->verify_captcha) {
            $c->session(auth => 1);
            $c->flash(username => $c->param('username'));
            return $c->redirect_to('home');
        }
        else {
            $c->flash('error' => 'Captcha verification failed');
            $c->redirect_to('index');
        }
    }
    $c->flash('error' => 'Wrong login/password');
    $c->redirect_to('index');
} => 'login';

get '/logout' => sub {
    my $c = shift;
    delete $c->session->{auth};
    $c->redirect_to('index');
} => 'logout';

# https://docs.mojolicious.org/Mojolicious/Lite#Under
under sub {
    my $c = shift;
    return 1 if ($c->session('auth') // '') eq '1';

    $c->render('denied');
};

get '/home' => sub {
    my $c = shift;
    $c->render();
} => 'home';

app->start;

__DATA__


@@ index.html.ep
<html>
    <head>
        <link href="https://fonts.googleapis.com/css?family=Nunito:200,600" rel="stylesheet">
        <script src="https://www.google.com/recaptcha/api.js" async defer></script>
    </head>
    <body>
        %= t h1 => 'Login'

        % if (flash('error')) {
            <h2 style="color:red"><%= flash('error') %></h2>
        % }

        %= form_for login => (method => 'post') => begin
            <label>username:</label> <%= text_field 'username' %>
        <br /><br />
            <label>password:</label> <%= password_field 'password' %>
        <br /><br />
            <div class="g-recaptcha" data-sitekey="<Your Site-key>"></div>
        %= submit_button 'Log in'
        %= end
    </body>
</html>


@@ home.html.ep
%= t h1 => 'Home Page'
<h2 style="color:green">Hello <%= flash('username') %></h2>
<a href="<%= url_for('logout') %>">Logout</a>


@@ denied.html.ep
%= t h2 => 'Access Denied'
<a href="<%= url_for('index') %>">Login</a>

