package Builder::Image;
use Moose;
use Data::Dumper;
use Types::Standard qw(ArrayRef InstanceOf);
use Carp;
use Mojo::Promise;
use feature "signatures";


has "name" => (
    is       => "rw",
    isa      => "Str",
    required => 1
);

has "deps" => (
    is         => "rw",
    isa        => ArrayRef [ InstanceOf [ "Builder::Image" ] ],
    required   => 0,
    auto_deref => 1
);

has "built" => (
    is      => "rw",
    isa     => "Bool",
    default => 0
);

sub deferRun {
    my ($self, $path) = @_;
    my $promise = Mojo::Promise->new;

    print "  🚀  Building: " . $self->name . "\n";
    my $cmdBuild = sprintf "/usr/bin/packer build -machine-readable %s/packer/%s/docker_basic.json.pkr.hcl", $path, $self->name;
    my $logFile = sprintf "%s/build.log", $path;
    close STDOUT;
    open STDOUT, ">>", $logFile || die $!;
    system($cmdBuild);
    close STDOUT;
    open STDOUT, ">>", "/dev/tty" || die $!;

    open my $fh, "<", $logFile || die $!;
    my @output = <$fh>;
    close $fh;
    my $success = @output[@output - 1] =~ /Imported Docker image/;
    
    unless ($success) {
        $promise->reject("  ☠️  Build failure: " . $self->name);
    }
    else {
        $promise->resolve("  🎉  Build success: " . $self->name);
    }
    return $promise;
}

sub runBuild {
    my ($self, $path) = @_;

    $self->deferRun($path)->then(sub($message) {
        print $message, "\n";
        $self->built(1);
    })->catch(sub($message) {
        croak $message;
    })->wait;
}

sub build {
    my $self = shift;
    my $path = shift;

    return if $self->built;

    foreach my $dep ($self->deps) {
        $dep->build($path);
    }

    $self->runBuild($path);
}

no Moose;
__PACKAGE__->meta->make_immutable;

