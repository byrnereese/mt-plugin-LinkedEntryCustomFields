
package RightFieldsConvert::App;

use MT::Util qw( format_ts relative_date );

sub field_html_params {
    my ($field_type, $tmpl_type, $param) = @_;
    if ($param->{value}) {
        my $e = MT->model('entry')->load($param->{value});
        $param->{field_preview} = $e->title if $e;
    }
    @{$param}{qw( field_blog_id field_categories )} = split /\s*,\s*/, $param->{options}, 2;
}

sub inject_addl_field_settings {
    my ($cb, $app, $param, $tmpl) = @_;
    return 1 if $param->{type} && $param->{type} ne 'entry';

    # Inject settings template code.
    my $addl_settings = MT->component('RightFieldsConvert')->load_tmpl('addl_settings.mtml');
    my $new_node = $tmpl->createElement('section');
    $new_node->innerHTML($addl_settings->text);
    $tmpl->insertAfter($new_node, $tmpl->getElementById('options'));

    # Add supporting params for our new template code.
    my ($blog_id, $options_categories) = split /\s*,\s*/, $param->{options}, 2;
    my @blogs = map { +{
        blog_id       => $_->id,
        blog_name     => $_->name,
        blog_selected => ($_->id == $blog_id ? 1 : 0)
    } } MT->model('blog')->load();
    $param->{blogs} = \@blogs;
    $param->{entry_categories} = $options_categories || q{};

    return 1;
}

sub presave_field {
    my ($cb, $app, $obj, $original) = @_;

    my $blog_id = $app->param('entry_blog') || '0';
    my $cats    = $app->param('entry_categories') || '';

    my $options = $cats ? join(q{,}, $blog_id, $cats) : $blog_id;

    for my $field ($obj, $original) {
        $field->options($options);
    }
    
    return 1;
}

sub list_entry_mini {
    my $app = shift;
    my (%terms, %args);

    my $blog_id = $app->param('blog_id')
        or return $app->errtrans('No blog_id');
    $terms{blog_id} = $blog_id;

    if (my $cats = $app->param('cat_ids')) {
        my @cats = split /\s*,\s*/, $cats;
        $args{join} = MT::Placement->join_on('entry_id', {
            blog_id     => $blog_id,
            category_id => \@cats,
        });
    }

    my $plugin = MT->component('RightFieldsConvert') or die "OMG NO COMPONENT!?!";
    my $tmpl = $plugin->load_tmpl('entry_list.mtml');
    return $app->listing({
        type => 'entry',
        template => $tmpl,
        params => {
            edit_blog_id => $blog_id,
            edit_field   => $app->param('edit_field'),
        },
        code => sub {
            my ($obj, $row) = @_;
            $row->{'status_' . lc MT::Entry::status_text($obj->status)} = 1;
            $row->{entry_permalink} = $obj->permalink
                if $obj->status == MT::Entry->RELEASE();
            if (my $ts = $obj->authored_on) {
                my $date_format = MT::App::CMS->LISTING_DATE_FORMAT();
                my $datetime_format = MT::App::CMS->LISTING_DATETIME_FORMAT();
                $row->{created_on_formatted} = format_ts($date_format, $ts, $obj->blog,
                    $app->user ? $app->user->preferred_language : undef);
                $row->{created_on_time_formatted} = format_ts($datetime_format, $ts, $obj->blog,
                    $app->user ? $app->user->preferred_language : undef);
                $row->{created_on_relative} = relative_date($ts, time, $obj->blog);
            }
            return $row;
        },
        terms => \%terms,
        args  => \%args,
        limit => 10,
    });
}

sub select_entry {
    my $app = shift;

    my $entry_id = $app->param('id')
        or return $app->errtrans('No id');
    my $entry = MT->model('entry')->load($entry_id)
        or return $app->errtrans('No entry #[_1]', $entry_id);
    my $edit_field = $app->param('edit_field')
        or return $app->errtrans('No edit_field');

    my $plugin = MT->component('RightFieldsConvert') or die "OMG NO COMPONENT!?!";
    my $tmpl = $plugin->load_tmpl('select_entry.mtml', {
        entry_id    => $entry->id,
        entry_title => $entry->title,
        edit_field  => $edit_field,
    });
    return $tmpl;
}

sub convert_rf2cf {
    my $app = shift;
}

1;

