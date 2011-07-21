use 5.010001;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'Roku::DVP::Remote',
    VERSION_FROM => 'lib/Roku/DVP/Remote.pm',
    PREREQ_PM    => {
        'URI'                    => '1.56',
        'Readonly'               => '1.03',
        'IO::Socket::INET'       => '1.31',
        'Net::Ifconfig::Wrapper' => '0.11',
        'Net::Ping'              => '2.36',
        'XUL::Gui'               => '0.63',
        'Env'                    => '1.00',
    },
    (
        $] >= 5.005
        ? ( ABSTRACT_FROM => 'lib/Roku/DVP/Remote.pm',
            AUTHOR => 'Dylan Doxey <dylan.doxey@gmail.com>'
        )
        : ()
    ),
);
